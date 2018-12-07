open Lwt.Infix

module type LambdaIO = sig
  type t

  val of_yojson: Yojson.Safe.json -> (t, string) result
  val to_yojson: t -> Yojson.Safe.json
end

module Make (Event : LambdaIO) (Response : LambdaIO) = struct
  type 'a runtime = {
    client: Client.t;
    settings: Config.function_settings;
    handler: Event.t -> Context.t -> 'a;
    max_retries: int;
    lift: 'a -> (Response.t, string) result Lwt.t;
  }

  let make ~handler ~max_retries ~settings ~lift client =
    { client; settings; max_retries; handler; lift;  }

  let rec get_next_event ?error runtime retries =
    match error with
    | Some err when retries > runtime.max_retries ->
        begin match Errors.request_id err with
        | Some req_id ->
          Client.event_error runtime.client req_id err
        | None ->
          Client.fail_init runtime.client err
        end |> ignore;
        (*
        * these errors are not recoverable. Either we can't communicate with the
        * runtime APIs or we cannot parse the event. panic to restart the
        * environment.
        *)
        failwith "Could not retrieve next event"
    | _ ->
      Client.next_event runtime.client >>= function
      | Ok(ev_data, invocation_ctx) ->
        begin match ev_data |> Yojson.Safe.from_string |> Event.of_yojson with
        | Ok ev ->
          let handler_ctx = Context.make
            ~invoked_function_arn:invocation_ctx.invoked_function_arn
            ~aws_request_id:invocation_ctx.aws_request_id
            ~xray_trace_id:invocation_ctx.xray_trace_id
            ~client_context:invocation_ctx.client_context
            ~identity:invocation_ctx.identity
            ~deadline:invocation_ctx.deadline
            runtime.settings in
          Lwt.return (ev, handler_ctx)
        | Error err ->
          let error = Errors.make_runtime_error
            ~recoverable:true
            ~request_id:invocation_ctx.aws_request_id
            (Printf.sprintf "Could not unserialize from JSON: %s" err) in
          get_next_event ~error runtime (retries + 1)
        | exception _ ->
          let error = Errors.make_runtime_error
            ~recoverable:false
            ~request_id:invocation_ctx.aws_request_id
            (Printf.sprintf "Could not parse event to type: %s" ev_data) in
          get_next_event ~error runtime (retries + 1)
        end
      | Error e -> get_next_event ~error:e runtime (retries + 1)

  let invoke { lift; handler } event ctx =
    lift (handler event ctx)

  let rec start runtime =
    let open Lwt.Infix in
    get_next_event runtime 0 >>= fun (event, ctx) ->
    let request_id = ctx.aws_request_id in
    invoke runtime event ctx >>= function
    | Ok response ->
      let response_json = Response.to_yojson response in
      Client.event_response runtime.client request_id response_json >>= begin function
      | Ok _ -> start runtime
      | Error e ->
        if not (Errors.is_recoverable e) then
          Client.fail_init runtime.client e >>= fun _ ->
          Logs_lwt.err (fun m ->
            m "Could not send error response %s" (Errors.message e)) >>= fun () ->
          failwith "Could not send error response";
        else
          start runtime
      end
    | Error msg ->
      let handler_error = Errors.make_handler_error msg in
      Client.event_error runtime.client request_id handler_error >>= function
      | Ok _ -> start runtime
      | Error e ->
        if not (Errors.is_recoverable e) then
          Logs_lwt.err (fun m ->
            m "Could not send error response %s" (Errors.message e)) >>= fun () ->
          Client.fail_init runtime.client e >>= fun _ ->
          failwith "Could not send error response";
        else
          start runtime
end
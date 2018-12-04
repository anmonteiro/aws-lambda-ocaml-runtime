module type LambdaIO = sig
  type t

  val of_yojson: Yojson.Safe.json -> (t, string) result
  val to_yojson: t -> Yojson.Safe.json
end

module Make (Event : LambdaIO) (Response : LambdaIO) = struct
  type runtime = {
    client: Client.t;
    settings: Config.function_settings;
    handler: Event.t -> Context.t -> (Response.t, string) result;
    max_retries: int
  }

  let make ~handler ~max_retries ~settings client =
    { client; settings; handler; max_retries }

  let rec get_next_event ?error runtime retries =
    match error with
    | Some err when retries > runtime.max_retries ->
        begin match Errors.request_id err with
        | Some req_id ->
          Client.event_error runtime.client req_id err |> ignore
        | None ->
          Client.fail_init runtime.client err
        end;
        (*
        * these errors are not recoverable. Either we can't communicate with the
        * runtime APIs or we cannot parse the event. panic to restart the
        * environment.
        *)
        failwith "Could not retrieve next event"
    | _ ->
      begin match Client.next_event runtime.client with
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
          (ev, handler_ctx)
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
      end

  let invoke runtime event ctx =
    runtime.handler event ctx

  let start runtime =
    while true do
      let event, ctx = get_next_event runtime 0 in
      let request_id = ctx.aws_request_id in
      match invoke runtime event ctx with
      | Ok response ->
        let response_json = Response.to_yojson response in
        begin match Client.event_response runtime.client request_id response_json with
        | Ok _ -> ()
        | Error e ->
          if not (Errors.is_recoverable e) then begin
            Client.fail_init runtime.client e;
            failwith "Could not send error response"
          end;
        end
      | Error msg ->
        let handler_error = Errors.make_handler_error msg in
        begin match Client.event_error runtime.client request_id handler_error with
        | Ok _ -> ()
        | Error e ->
          if not (Errors.is_recoverable e) then begin
            Client.fail_init runtime.client e;
            failwith "Could not send error response"
          end;
        end
    done
end
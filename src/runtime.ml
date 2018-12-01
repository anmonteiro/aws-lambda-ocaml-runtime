open Errors

type 'a runtime = {
  client: Client.t;
  settings: Config.function_settings;
  handler: Yojson.Safe.json -> Context.t -> (Yojson.Safe.json, Errors.t) result;
  max_retries: int
}

let make ~handler ~max_retries ~settings client =
  { client; settings; handler; max_retries }

let rec get_next_event ?error runtime retries =
  match error with
  | Some err when retries > runtime.max_retries ->
      let RuntimeError { request_id } | ApiError { request_id } = err in
      begin match request_id with
      | Some req_id ->
        Client.event_error runtime.client req_id err |> ignore
      | None ->
        Client.fail_init runtime.client err
      end;
      (*
       * these errors are not recoverable. Either we can't communicate with the runtie APIs
       * or we cannot parse the event. panic to restart the environment.
       *)
      failwith "Could not retrieve next event"
  | _ ->
    begin match Client.next_event runtime.client with
    | Ok(ev_data, invocation_ctx) ->
      begin try
        let ev = Yojson.Safe.from_string ev_data in
        let handler_ctx = Context.make
          ~invoked_function_arn:invocation_ctx.invoked_function_arn
          ~aws_request_id:invocation_ctx.aws_request_id
          ~xray_trace_id:invocation_ctx.xray_trace_id
          ~client_context:invocation_ctx.client_context
          ~identity:invocation_ctx.identity
          ~deadline:invocation_ctx.deadline
          runtime.settings in
        (ev, handler_ctx)
      with
      | _ ->
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
      begin match Client.event_response runtime.client request_id response with
      | Ok _ -> ()
      | Error e ->
        if not (Errors.is_recoverable e) then begin
          Client.fail_init runtime.client e;
          failwith "Could not send error response"
        end;
      end
    | Error e ->
      begin match Client.event_error runtime.client request_id e with
      | Ok _ -> ()
      | Error e ->
        if not (Errors.is_recoverable e) then begin
          Client.fail_init runtime.client e;
          failwith "Could not send error response"
        end;
      end
  done




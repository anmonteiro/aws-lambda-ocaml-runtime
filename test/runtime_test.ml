open Lambda_runtime_private
open Test_common

let error = ref false

module MockConfigProvider = struct
  let get_function_settings () =
    if !error then
      Error (Errors.make_runtime_error ~recoverable:false "Mock error")
    else
      Ok {
        Config.function_name = "MockFunction";
        memory_size = 128;
        version = "$LATEST";
        log_stream = "LogStream";
        log_group = "LogGroup";
      }

  let get_runtime_api_endpoint () =
    if !error then
      Error (Errors.make_runtime_error ~recoverable:false "Mock error")
    else
      Ok "http://localhost:8080"

  let get_deadline secs =
    let now_ms = Unix.gettimeofday () *. 1000. in
    let deadline_f = now_ms +. (float_of_int secs) *. 1000. in
    Int64.of_float deadline_f

  let test_context deadline = {
    Context.memory_limit_in_mb = 128;
    function_name = "test_func";
    function_version = "$LATEST";
    invoked_function_arn = "arn:aws:lambda";
    aws_request_id = "123";
    xray_trace_id = "123";
    log_stream_name = "logStream";
    log_group_name = "logGroup";
    client_context = None;
    identity = None;
    deadline = get_deadline(deadline);
  }
end

let suite = [
  ("simple handler invocation", `Quick, fun () ->
    let handler _event _ctx =
      Ok (`String "Hello")
    in
    match MockConfigProvider.get_runtime_api_endpoint () with
    | Error _ -> Alcotest.fail "Could not get runtime endpoint"
    | Ok runtime_api_endpoint ->
      let client = Client.make runtime_api_endpoint in
      match MockConfigProvider.get_function_settings () with
      | Error _ -> Alcotest.fail "Could not load environment config"
      | Ok settings ->
        let runtime = Runtime.make
          ~handler
          ~max_retries:3
          ~settings
          client
        in
        let output = Runtime.invoke runtime (`String "test") (MockConfigProvider.test_context 10)
        in
        match output with
        | Ok result ->
          Alcotest.check yojson "runtime invoke output" (`String "Hello") result
        | Error e -> Alcotest.fail (Errors.to_json e |> Yojson.Safe.to_string))
]
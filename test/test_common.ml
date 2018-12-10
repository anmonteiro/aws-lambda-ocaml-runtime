open Lambda_runtime_private

let yojson = (module struct
  type t = Yojson.Safe.json

  let pp formatter t =
    Format.pp_print_text formatter (Yojson.Safe.pretty_to_string t)

  let equal = (=)
end : Alcotest.TESTABLE with type t = Yojson.Safe.json)

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
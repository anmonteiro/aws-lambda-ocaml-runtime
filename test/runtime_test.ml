open Test_common

module Runtime = Lambda_runtime__.Runtime.Make (Lambda_runtime__.Lambda_json.Id) (Lambda_runtime__.Lambda_json.Id)

let request  = `String "test"
let test_runtime = test_runtime_generic (module Runtime) ~lift:Lwt.return request
let test_async_runtime = test_runtime_generic (module Runtime) ~lift:id request

exception User_code_exception

let suite = [
  ("successful handler invocation", `Quick, fun () ->
    let handler _event _ctx =
      Ok (`String "Hello")
    in
    test_runtime handler (fun output ->
      match output with
      | Ok result ->
        Alcotest.check yojson "runtime invoke output" (`String "Hello") result
      | Error e -> Alcotest.fail e));
  ("failed handler invocation", `Quick, fun () ->
    let handler _event _ctx =
      Error "I failed"
    in
    test_runtime handler (fun output ->
      match output with
      | Ok result ->
        let result_str = Yojson.Safe.to_string result in
        Alcotest.fail
          (Printf.sprintf "Expected to get an error but the call succeeded with: %s" result_str)
      | Error e ->
        Alcotest.(check string "Runtime invoke error" "I failed" e)));
  ("simple asynchronous handler invocation", `Quick, fun () ->
    let handler _event _ctx =
      Lwt_result.return (`String "Hello")
    in
    test_async_runtime handler (fun output ->
      match output with
      | Ok result ->
        Alcotest.check yojson "runtime invoke output" (`String "Hello") result
      | Error e -> Alcotest.fail e));
  ("failed handler invocation", `Quick, fun () ->
    let handler _event _ctx =
      raise User_code_exception
    in
    test_runtime handler (fun output ->
      match output with
      | Ok result ->
        let result_str = Yojson.Safe.to_string result in
        Alcotest.fail
          (Printf.sprintf "Expected to get an error but the call succeeded with: %s" result_str)
      | Error e -> Alcotest.(check string "Runtime invoke error" "Handler raised: Runtime_test.User_code_exception\n" e)));
]
open Lambda_runtime_private
open Test_common

let test_runtime handler test_fn =
  match MockConfigProvider.get_runtime_api_endpoint () with
  | Error _ -> Alcotest.fail "Could not get runtime endpoint"
  | Ok runtime_api_endpoint ->
    let client = Client.make runtime_api_endpoint in
    match MockConfigProvider.get_function_settings () with
    | Error _ -> Alcotest.fail "Could not load environment config"
    | Ok settings ->
      let runtime = Runtime.make
        ~handler
        ~lift:Lwt.return
        ~max_retries:3
        ~settings
        client
      in
      let output = Runtime.invoke runtime (`String "test") (MockConfigProvider.test_context 10)
      in
      test_fn (Lwt_main.run output)

let id: 'a. 'a -> 'a = fun x -> x

let test_async_runtime handler test_fn =
  match MockConfigProvider.get_runtime_api_endpoint () with
  | Error _ -> Alcotest.fail "Could not get runtime endpoint"
  | Ok runtime_api_endpoint ->
    let client = Client.make runtime_api_endpoint in
    match MockConfigProvider.get_function_settings () with
    | Error _ -> Alcotest.fail "Could not load environment config"
    | Ok settings ->
      let runtime = Runtime.make
        ~handler
        ~lift:id
        ~max_retries:3
        ~settings
        client
      in
      let output = Runtime.invoke runtime (`String "test") (MockConfigProvider.test_context 10)
      in
      test_fn (Lwt_main.run output)

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
      | Error e -> Alcotest.fail e))
]
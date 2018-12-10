open Lambda_runtime_private
open Test_common

module Json_runtime = struct
  type request = Yojson.Safe.json
  type response = Yojson.Safe.json
  include Runtime
end

let request  = `String "test"
let test_runtime = test_runtime_generic (module Json_runtime) ~lift:Lwt.return request
let test_async_runtime = test_runtime_generic (module Json_runtime) ~lift:id request

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
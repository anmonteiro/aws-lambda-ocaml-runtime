open Lambda_runtime
open Test_common

module Http = Lambda_runtime__.Lambda_http

let apigw_response = (module struct
  type t = Http.api_gateway_proxy_response

  let pp formatter t =
    Format.pp_print_text
      formatter
      (t |> Http.API_gateway_response.to_yojson |> Yojson.Safe.pretty_to_string)

  let equal = (=)
end : Alcotest.TESTABLE with type t = Http.api_gateway_proxy_response)

let request = Test_common.make_test_request (module Http.API_gateway_request) "apigw_real"

let test_fixture = Test_common.test_fixture (module Http.API_gateway_request)
let test_runtime = test_runtime_generic (module Http) ~lift:Lwt.return request
let test_async_runtime = test_runtime_generic (module Http) ~lift:id request

let response = Http.{
  status_code = 200;
  headers = StringMap.empty;
  body = "Hello";
  is_base64_encoded = false
}

let suite = [
  ("deserialize (mock) API Gateway Proxy Request", `Quick, fun () ->
    test_fixture "apigw");
  ("deserialize (real world) API Gateway Proxy Request", `Quick, fun () ->
    test_fixture "apigw_real_trimmed");
  ("successful handler invocation", `Quick, fun () ->
    let handler _event _ctx = Ok response in
    test_runtime handler (fun output ->
      match output with
      | Ok result -> Alcotest.check apigw_response "runtime invoke output" response result
      | Error e -> Alcotest.fail e));
  ("failed handler invocation", `Quick, fun () ->
    let handler _event _ctx =
      Error "I failed"
    in
    test_runtime handler (fun output ->
      match output with
      | Ok response ->
        let result_str = response
        |> Http.API_gateway_response.to_yojson
        |> Yojson.Safe.pretty_to_string
        in
        Alcotest.fail
          (Printf.sprintf "Expected to get an error but the call succeeded with: %s" result_str)
      | Error e ->
        Alcotest.(check string "Runtime invoke error" "I failed" e)));
  ("simple asynchronous handler invocation", `Quick, fun () ->
    let handler _event _ctx =
      Lwt_result.return response
    in
    test_async_runtime handler (fun output ->
      match output with
      | Ok result -> Alcotest.check apigw_response "runtime invoke output" response result
      | Error e -> Alcotest.fail e))
]
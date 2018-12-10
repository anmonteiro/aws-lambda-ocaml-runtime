open Lambda_runtime_private
open Http
open Test_common

let apigw_response = (module struct
  type t = api_gateway_proxy_response

  let pp formatter t =
    Format.pp_print_text
      formatter
      (t |> API_gateway_response.to_yojson |> Yojson.Safe.pretty_to_string)

  let equal = (=)
end : Alcotest.TESTABLE with type t = api_gateway_proxy_response)

let read_all path =
  let file = open_in path in
  try
      really_input_string file (in_channel_length file)
  with exn ->
    close_in file;
    raise exn

let rec order_keys = function
| `Assoc kvs ->
  let bindings = List.map (fun (k, v) -> k, order_keys v) kvs in
  `Assoc (List.sort (fun (k1, _) (k2, _) -> compare k1 k2) bindings)
| x -> x

let test_fixture path =
  let fixture = read_all (Printf.sprintf "fixtures/%s" path) |> Yojson.Safe.from_string
  in
  match API_gateway_request.of_yojson fixture with
  | Ok req ->
    Alcotest.check yojson "roundtripping" (order_keys fixture) (API_gateway_request.to_yojson req |> order_keys)
  | Error err -> Alcotest.fail err

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
      let fixture = read_all (Printf.sprintf "fixtures/apigw_real.json") |> Yojson.Safe.from_string
      in
      match API_gateway_request.of_yojson fixture with
      | Ok req ->
        let output = Runtime.invoke runtime req (MockConfigProvider.test_context 10)
        in
        test_fn (Lwt_main.run output)
      | Error err -> Alcotest.fail err

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
      let fixture = read_all (Printf.sprintf "fixtures/apigw_real.json") |> Yojson.Safe.from_string
      in
      match API_gateway_request.of_yojson fixture with
      | Ok req ->
        let output = Runtime.invoke runtime req (MockConfigProvider.test_context 10)
        in
        test_fn (Lwt_main.run output)
      | Error err -> Alcotest.fail err

module StringMap = Map.Make(String)
let response = {
  status_code = 200;
  headers = StringMap.empty;
  body = "Hello";
  is_base64_encoded = false
}

let suite = [
  ("deserialize (mock) API Gateway Proxy Request", `Quick, fun () ->
    test_fixture "apigw.json");
  ("deserialize (real world) API Gateway Proxy Request", `Quick, fun () ->
    test_fixture "apigw_real_trimmed.json");
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
        |> API_gateway_response.to_yojson
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
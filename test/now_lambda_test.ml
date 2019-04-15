open Test_common
open Now_lambda__
open Types

let now_lambda_response =
  (module struct
    open Types

    type t = Now_response.t

    let pp formatter t =
      Format.pp_print_text
        formatter
        (t |> Now_response.to_yojson |> Yojson.Safe.pretty_to_string)

    let equal = ( = )
  end
  : Alcotest.TESTABLE
    with type t = Now_response.t)

module Runtime =
  Lambda_runtime__.Runtime.Make (Types.Now_request) (Types.Now_response)

let request =
  Test_common.make_test_request (module Types.Now_request) "now_with_body"

let transform_internal json =
  match Yojson.Safe.Util.member "body" json with
  | `String s ->
    Yojson.Safe.from_string s
  | _ ->
    failwith "Expected body to be string"

let transform_b64_encoding = function
  | `Assoc kvs ->
    let kvs' =
      kvs
      |> List.map (function
             | ("body" as k), `String s ->
               k, `String (Base64.decode_exn s)
             | x ->
               x)
      (* Encoding is not part of the public format *)
      |> List.filter (function "encoding", _ -> false | _ -> true)
    in
    `Assoc kvs'
  | _ ->
    failwith "Expected body to be string"

let test_fixture = Test_common.test_fixture (module Types.Now_request)

let test_runtime =
  test_runtime_generic (module Runtime) ~lift:Lwt.return request

let test_async_runtime = test_runtime_generic (module Runtime) ~lift:id request

let response = Httpaf.Response.create `OK, ""

let suite =
  [ ( "deserialize Now Proxy Request without HTTP Body"
    , `Quick
    , fun () ->
        test_fixture ~transform_fixture:transform_internal "now_no_body" )
  ; ( "deserialize Now Proxy Request with HTTP Body"
    , `Quick
    , fun () ->
        test_fixture
          ~transform_fixture:(fun x ->
            x |> transform_internal |> transform_b64_encoding)
          "now_with_body" )
  ; ( "successful handler invocation"
    , `Quick
    , fun () ->
        let handler _event _ctx = Ok response in
        test_runtime handler (fun output ->
            match output with
            | Ok result ->
              Alcotest.check
                now_lambda_response
                "runtime invoke output"
                response
                result
            | Error e ->
              Alcotest.fail e) )
  ; ( "failed handler invocation"
    , `Quick
    , fun () ->
        let handler _event _ctx = Error "I failed" in
        test_runtime handler (fun output ->
            match output with
            | Ok response ->
              let result_str =
                response
                |> Types.Now_response.to_yojson
                |> Yojson.Safe.pretty_to_string
              in
              Alcotest.fail
                (Printf.sprintf
                   "Expected to get an error but the call succeeded with: %s"
                   result_str)
            | Error e ->
              Alcotest.(check string "Runtime invoke error" "I failed" e)) )
  ; ( "simple asynchronous handler invocation"
    , `Quick
    , fun () ->
        let handler _event _ctx = Lwt_result.return response in
        test_async_runtime handler (fun output ->
            match output with
            | Ok result ->
              Alcotest.check
                now_lambda_response
                "runtime invoke output"
                response
                result
            | Error e ->
              Alcotest.fail e) )
  ]

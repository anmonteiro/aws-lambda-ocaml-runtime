open Test_common
module Now = Now__

let now_lambda_response =
  (module struct
    open Now

    type t = Response.t

    let pp formatter t =
      Format.pp_print_text
        formatter
        (t |> Response.to_yojson |> Yojson.Safe.pretty_to_string)

    let equal = ( = )
  end : Alcotest.TESTABLE
    with type t = Now.Response.t)

module Runtime = struct
  include Lambda_runtime__.Runtime.Make (Now.Reqd) (Now.Response)

  type event = Now.Reqd.t

  type response = Now.Response.t
end

let request = Test_common.make_test_request (module Now.Reqd) "now_with_body"

let test_fixture = Test_common.test_fixture (module Now.Reqd)

let test_runtime =
  test_runtime_generic (module Runtime) ~lift:Lwt.return request

let test_async_runtime = test_runtime_generic (module Runtime) ~lift:id request

let response = Httpaf.Response.create `OK, ""

let suite =
  [ ( "deserialize Now Proxy Request without HTTP Body"
    , `Quick
    , test_fixture "now_no_body" )
  ; ( "deserialize Now Proxy Request with HTTP Body"
    , `Quick
    , test_fixture "now_with_body" )
  ; ( "successful handler invocation"
    , `Quick
    , test_runtime
        (fun _event _ctx -> Ok response)
        (fun output ->
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
    , test_runtime
        (fun _event _ctx -> Error "I failed")
        (fun output ->
          match output with
          | Ok response ->
            let result_str =
              response
              |> Now.Response.to_yojson
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
    , test_async_runtime
        (fun _event _ctx -> Lwt_result.return response)
        (fun output ->
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

module StringMap = Lambda_runtime.StringMap
module Response = Httpaf.Response

type now_proxy_response =
  { status_code : int [@key "statusCode"]
  ; headers : string StringMap.t
  ; body : string
  ; encoding : string option
  }
[@@deriving yojson]

type t = Response.t * string

let to_yojson ({ Response.status; headers; _ }, body) =
  let now_proxy_response =
    { status_code = Httpaf.Status.to_code status
    ; headers = Message.headers_to_string_map headers
    ; body
    ; encoding = None
    }
  in
  now_proxy_response_to_yojson now_proxy_response

let of_yojson json =
  match now_proxy_response_of_yojson json with
  | Error _ as error ->
    error
  | Ok { status_code; headers; body; encoding } ->
    let headers = Message.string_map_to_headers headers in
    let status = Httpaf.Status.of_code status_code in
    let body =
      match Message.decode_body ~encoding (Some body) with
      | Some body ->
        body
      | None ->
        ""
    in
    Ok (Response.create ~headers status, body)

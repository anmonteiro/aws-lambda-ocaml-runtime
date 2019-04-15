module StringMap = Lambda_runtime.StringMap

type now_proxy_request =
  { path : string
  ; http_method : string [@key "method"]
  ; host : string
  ; headers : string StringMap.t
  ; body : string option [@default None]
  ; encoding : string option [@default None]
  }
[@@deriving yojson]

type now_proxy_response =
  { status_code : int [@key "statusCode"]
  ; headers : string StringMap.t
  ; body : string
  ; encoding : string option
  }
[@@deriving yojson]

type now_event =
  { action : string [@key "Action"]
  ; body : string
  }
[@@deriving of_yojson]

let decode_body ~encoding body =
  match body, encoding with
  | None, _ ->
    None
  | Some body, Some "base64" ->
    (match Base64.decode body with Ok body -> Some body | Error _ -> None)
  | Some body, _ ->
    (* base64 is the only supported encoding *)
    Some body

let string_map_to_headers ?(init = Httpaf.Headers.empty) map =
  StringMap.fold
    (fun name value hs -> Httpaf.Headers.add hs name value)
    map
    init

let headers_to_string_map hs =
  Httpaf.Headers.fold ~f:StringMap.add ~init:StringMap.empty hs

module Now_request = struct
  module Request = Httpaf.Request

  type t = Request.t * string option

  let of_yojson json =
    match now_event_of_yojson json with
    | Ok { body = event_body; _ } ->
      (match
         Yojson.Safe.from_string event_body |> now_proxy_request_of_yojson
       with
      | Ok { body; encoding; path; http_method; host; headers } ->
        let meth = Httpaf.Method.of_string http_method in
        let headers =
          string_map_to_headers
            ~init:
              (match
                 StringMap.(find_opt "host" headers, find_opt "Host" headers)
               with
              | Some _, _ | _, Some _ ->
                Httpaf.Headers.empty
              | None, None ->
                Httpaf.Headers.of_list [ "Host", host ])
            headers
        in
        let request = Httpaf.Request.create ~headers meth path in
        Ok (request, decode_body ~encoding body)
      | Error _ ->
        Error "Failed to parse event to Now request type"
      | exception Yojson.Json_error error ->
        Error
          (Printf.sprintf "Failed to parse event to Now request type: %s" error))
    | Error _ ->
      Error "Failed to parse event to Now request type"

  let to_yojson ({ Request.meth; target; headers; _ }, body) =
    let now_proxy_request =
      { path = target
      ; http_method = Httpaf.Method.to_string meth
      ; host =
          (match Httpaf.Headers.get headers "Host" with
          | None ->
            ""
          | Some host ->
            host)
      ; headers = headers_to_string_map headers
      ; body
      ; encoding = None
      }
    in
    now_proxy_request_to_yojson now_proxy_request
end

module Now_response = struct
  module Response = Httpaf.Response

  type t = Response.t * string

  let to_yojson ({ Response.status; headers; _ }, body) =
    let now_proxy_response =
      { status_code = Httpaf.Status.to_code status
      ; headers = headers_to_string_map headers
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
      let headers = string_map_to_headers headers in
      let status = Httpaf.Status.of_code status_code in
      let body =
        match decode_body ~encoding (Some body) with
        | Some body ->
          body
        | None ->
          ""
      in
      Ok (Response.create ~headers status, body)
end

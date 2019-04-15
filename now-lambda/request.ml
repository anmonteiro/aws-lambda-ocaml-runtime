module StringMap = Lambda_runtime.StringMap
module Request = Httpaf.Request

type now_proxy_request =
  { path : string
  ; http_method : string [@key "method"]
  ; host : string
  ; headers : string StringMap.t
  ; body : string option [@default None]
  ; encoding : string option [@default None]
  }
[@@deriving yojson]

type now_event =
  { action : string [@key "Action"]
  ; body : string
  }
[@@deriving of_yojson]

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
        Message.string_map_to_headers
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
      Ok (request, Message.decode_body ~encoding body)
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
    ; headers = Message.headers_to_string_map headers
    ; body
    ; encoding = None
    }
  in
  now_proxy_request_to_yojson now_proxy_request

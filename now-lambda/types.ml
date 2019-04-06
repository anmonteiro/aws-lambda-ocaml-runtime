[@@@ocaml.warning "-39"]

type now_proxy_request_internal =
  { path : string
  ; http_method : string [@key "method"]
  ; host : string
  ; headers : string Lambda_runtime.StringMap.t
  ; body : string option [@default None]
  ; encoding : string option [@default None]
  }
[@@deriving yojson]

type now_proxy_request =
  { path : string
  ; http_method : string [@key "method"]
  ; host : string
  ; headers : string Lambda_runtime.StringMap.t
  ; body : string option [@default None]
  }
[@@deriving yojson]

type now_proxy_response =
  { status_code : int [@key "statusCode"]
  ; headers : string Lambda_runtime.StringMap.t
  ; body : string
  ; encoding : string option
  }
[@@deriving yojson]

type now_event =
  { action : string [@key "Action"]
  ; body : string
  }
[@@deriving of_yojson]

[@@@ocaml.warning "+39"]

module Now_request = struct
  [@@@ocaml.warning "-39-32"]

  type t = now_proxy_request [@@deriving yojson]

  [@@@ocaml.warning "+39"]

  let of_yojson json =
    match now_event_of_yojson json with
    | Ok { body = body_str } ->
      (match
         Yojson.Safe.from_string body_str
         |> now_proxy_request_internal_of_yojson
       with
      | Ok { body; encoding; path; http_method; host; headers } ->
        let body =
          match body, encoding with
          | None, _ ->
            None
          | Some body, Some "base64" ->
            (match Base64.decode body with
            | Ok body ->
              Some body
            | Error _ ->
              None)
          | Some body, _ ->
            Some body
        in
        Ok { path; http_method; host; headers; body }
      | Error _ ->
        Error "Failed to parse event to Now request type"
      | exception Yojson.Json_error error ->
        Error
          (Printf.sprintf "Failed to parse event to Now request type: %s" error))
    | Error _ ->
      Error "Failed to parse event to Now request type"
end

module Now_response = struct
  [@@@ocaml.warning "-39"]

  type t = now_proxy_response [@@deriving yojson]
end

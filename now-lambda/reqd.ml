type response_state =
  | Waiting
  | Complete of Response.t

type t =
  { request : Httpaf.Request.t
  ; request_body : string option
  ; mutable response_state : response_state
  }

type response = Httpaf.Response.t * string

let request { request; _ } = request

let request_body { request_body; _ } = request_body

let response { response_state; _ } =
  match response_state with
  | Waiting ->
    None
  | Complete (response, _) ->
    Some response

let response_exn { response_state; _ } =
  match response_state with
  | Waiting ->
    failwith "Now_lambda.Reqd.response_exn: response has not started"
  | Complete (response, _) ->
    response

(* Responding *)

let respond_with_string t response str =
  match t.response_state with
  | Waiting ->
    let ret = response, str in
    t.response_state <- Complete ret;
    ret
  | Complete _ ->
    failwith "Now_lambda.Reqd.respond_with_string: Response already complete"

let respond_with_bigstring t response ?(off = 0) ?len bstr =
  match t.response_state with
  | Waiting ->
    let len =
      match len with Some len -> len | None -> Bigstringaf.length bstr
    in
    let ret = response, Bigstringaf.substring ~off ~len bstr in
    t.response_state <- Complete ret;
    ret
  | Complete _ ->
    failwith
      "Now_lambda.Reqd.respond_with_bigstring: Response already complete"

(* Serializing / Deserializing *)

let of_yojson json =
  match Request.of_yojson json with
  | Ok (request, request_body) ->
    Ok { request; request_body; response_state = Waiting }
  | Error _ as error ->
    error

let to_yojson { request; request_body; _ } =
  Request.to_yojson (request, request_body)

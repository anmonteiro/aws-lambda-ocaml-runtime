(*----------------------------------------------------------------------------
 *  Copyright (c) 2019 António Nuno Monteiro
 *
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *  this list of conditions and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *
 *  3. Neither the name of the copyright holder nor the names of its
 *  contributors may be used to endorse or promote products derived from this
 *  software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *---------------------------------------------------------------------------*)

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

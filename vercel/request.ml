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
module Request = Piaf.Request
module Body = Piaf.Body
module Headers = Piaf.Headers

type vercel_proxy_request =
  { path : string
  ; http_method : string [@key "method"]
  ; host : string
  ; headers : string StringMap.t
  ; body : string option [@default None]
  ; encoding : string option [@default None]
  }
[@@deriving of_yojson]

type vercel_event =
  { action : string [@key "Action"]
  ; body : string
  }
[@@deriving of_yojson]

type t = Request.t

let of_yojson json =
  match vercel_event_of_yojson json with
  | Ok { body = event_body; _ } ->
    (match
       Yojson.Safe.from_string event_body |> vercel_proxy_request_of_yojson
     with
    | Ok { body; encoding; path; http_method; host; headers } ->
      let meth = Piaf.Method.of_string http_method in
      let headers =
        Message.string_map_to_headers
          ~init:
            (match
               StringMap.(find_opt "host" headers, find_opt "Host" headers)
             with
            | Some _, _ | _, Some _ ->
              Headers.empty
            | None, None ->
              Headers.of_list [ "Host", host ])
          headers
      in
      let body =
        match Message.decode_body ~encoding body with
        | None ->
          Body.empty
        | Some s ->
          Body.of_string s
      in
      let request =
        Request.create
          ~scheme:HTTP
          ~version:Piaf.Versions.HTTP.v1_1
          ~headers
          ~meth
          ~body
          path
      in
      Ok request
    | Error _ ->
      Error "Failed to parse event to Vercel request type"
    | exception Yojson.Json_error error ->
      Error
        (Printf.sprintf
           "Failed to parse event to Vercel request type: %s"
           error))
  | Error _ ->
    Error "Failed to parse event to Vercel request type"

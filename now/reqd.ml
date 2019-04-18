(*----------------------------------------------------------------------------
 *  Copyright (c) 2017 Inhabited Type LLC.
 *  Copyright (c) 2019 Antonio N. Monteiro.
 *
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 *  3. Neither the name of the author nor the names of his contributors
 *     may be used to endorse or promote products derived from this software
 *     without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE CONTRIBUTORS ``AS IS'' AND ANY EXPRESS
 *  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 *  DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE FOR
 *  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 *  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 *  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 *  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 *  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *---------------------------------------------------------------------------*)

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
    Ok ret
  | Complete _ ->
    Error "Now_lambda.Reqd.respond_with_string: Response already complete"

let respond_with_bigstring t response ?(off = 0) ?len bstr =
  match t.response_state with
  | Waiting ->
    let len =
      match len with Some len -> len | None -> Bigstringaf.length bstr
    in
    let ret = response, Bigstringaf.substring ~off ~len bstr in
    t.response_state <- Complete ret;
    Ok ret
  | Complete _ ->
    Error "Now_lambda.Reqd.respond_with_bigstring: Response already complete"

(* Serializing / Deserializing *)

let of_yojson json =
  match Request.of_yojson json with
  | Ok (request, request_body) ->
    Ok { request; request_body; response_state = Waiting }
  | Error _ as error ->
    error

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

module Response = Piaf.Response
module StringSet = Set.Make (String)

module Headers = struct
  include Piaf.Headers

  let to_yojson headers =
    let keys = StringSet.of_list (List.map fst (to_list headers)) in
    `Assoc
      (StringSet.fold
         (fun name acc ->
           let element =
             match get_multi headers name with
             | [ x ] -> name, `String x
             | xs -> name, `List (List.map (fun v -> `String v) xs)
           in
           element :: acc)
         keys
         [])
end

type vercel_proxy_response =
  { status_code : int [@key "statusCode"]
  ; headers : Headers.t
  ; body : string
  ; encoding : string option
  }
[@@deriving to_yojson]

type t = Response.t

let to_yojson { Response.status; headers; body; _ } =
  let body = Result.get_ok (Piaf.Body.to_string body) in
  let vercel_proxy_response =
    { status_code = Piaf.Status.to_code status; headers; body; encoding = None }
  in
  vercel_proxy_response_to_yojson vercel_proxy_response

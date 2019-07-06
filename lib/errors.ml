(*----------------------------------------------------------------------------
 *  Copyright (c) 2018 António Nuno Monteiro
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

type error_record =
  { msg : string
  ; (* stack_trace: string option; (* Option<backtrace::Backtrace>, *) *)
    (* The request id that generated this error *)
    request_id : string option
  ; (* Whether the error is recoverable or not. *)
    recoverable : bool
  }

type lambda_error =
  { error_message : string [@key "errorMessage"]
  ; error_type : string [@key "errorType"]
  }
[@@deriving to_yojson]

type _ t =
  | RuntimeError : error_record -> [ `unhandled ] t
  | ApiError : error_record -> [ `unhandled ] t
  | HandlerError : lambda_error -> [ `handled ] t

module Constants = struct
  let error_type_handled = "Handled"

  let error_type_unhandled = "Unhandled"
end

(* TODO: consider making `make_recoverable` / `make_unrecoverable` helpers *)
let make_runtime_error ?request_id ~recoverable msg =
  RuntimeError { msg; request_id; recoverable }

let make_api_error ?request_id ~recoverable msg =
  ApiError { msg; request_id; recoverable }

let make_handler_error msg =
  HandlerError
    { error_message = msg; error_type = Constants.error_type_handled }

let is_recoverable = function
  | ApiError { recoverable; _ } | RuntimeError { recoverable; _ } ->
    recoverable

let message : type a. a t -> string = function
  | HandlerError { error_message; _ } ->
    error_message
  | ApiError { msg; _ } ->
    msg
  | RuntimeError { msg; _ } ->
    msg

let request_id = function
  | ApiError { request_id; _ } ->
    request_id
  | RuntimeError { request_id; _ } ->
    request_id

let to_lambda_error : type a. ?handled:bool -> a t -> Yojson.Safe.t =
 fun ?(handled = true) error ->
  let make_lambda_error e =
    { error_message = e.msg
    ; error_type =
        (if handled then
           Constants.error_type_handled
        else
          Constants.error_type_unhandled)
    }
  in
  let lambda_error =
    match error with
    | HandlerError e ->
      e
    | ApiError e ->
      make_lambda_error e
    | RuntimeError e ->
      make_lambda_error e
  in
  lambda_error_to_yojson lambda_error

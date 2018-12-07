type error_record = {
  msg: string;
  (* stack_trace: string option; (* Option<backtrace::Backtrace>, *) *)
  (* The request id that generated this error *)
  request_id: string option;
  (* Whether the error is recoverable or not. *)
  recoverable: bool;
}

[@@@ocaml.warning "-39"]

type lambda_error = {
  error_message: string [@key "errorMessage"];
  error_type: string [@key "errorType"];
  (* TODO: do we need stack_trace / stackTrace even if always null? *)
}
[@@deriving yojson]

[@@@ocaml.warning "+39"]

type _ t =
  | RuntimeError : error_record -> [`unhandled] t
  | ApiError : error_record -> [`unhandled] t
  | HandlerError : lambda_error -> [`handled] t

module Constants = struct
  let error_type_handled = "Handled"
  let error_type_unhandled = "Unhandled"
end

(* TODO: consider making `make_recoverable` / `make_unrecoverable` helpers *)
let make_runtime_error ?request_id ~recoverable msg =
  RuntimeError { msg; request_id; recoverable;  }

let make_api_error ?request_id ~recoverable msg =
  ApiError { msg; request_id; recoverable;  }

let make_handler_error msg =
  HandlerError { error_message = msg; error_type = Constants.error_type_handled  }

let is_recoverable = function
  | ApiError { recoverable }
  | RuntimeError { recoverable } -> recoverable

let message: type a. a t -> string = function
  | HandlerError { error_message } -> error_message
  | ApiError { msg } -> msg
  | RuntimeError { msg } -> msg

let request_id = function
  | ApiError { request_id } -> request_id
  | RuntimeError { request_id } -> request_id

let to_lambda_error: type a. ?handled:bool -> a t -> Yojson.Safe.json =
  fun ?(handled=true) error ->
    let make_lambda_error e = {
      error_message = e.msg;
      error_type =
      if handled then Constants.error_type_handled
      else Constants.error_type_unhandled
    }
    in
    let lambda_error = match error with
    | HandlerError e -> e
    | ApiError e -> make_lambda_error e
    | RuntimeError e -> make_lambda_error e
    in
    lambda_error_to_yojson lambda_error
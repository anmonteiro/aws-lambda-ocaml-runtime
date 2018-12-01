type error_record = {
  msg: string;
  (* stack_trace: string option; (* Option<backtrace::Backtrace>, *) *)
  (* The request id that generated this error *)
  request_id: string option;
  (* Whether the error is recoverable or not. *)
  recoverable: bool;
}
[@@deriving yojson]

type t =
  | RuntimeError of error_record
  | ApiError of error_record

(* TODO: consider making `make_recoverable` / `make_unrecoverable` helpers *)
let make_runtime_error ?request_id ~recoverable msg =
  RuntimeError { msg; request_id; recoverable;  }

let make_api_error ?request_id ~recoverable msg =
  ApiError { msg; request_id; recoverable;  }

let is_recoverable = function
  | ApiError { recoverable }
  | RuntimeError { recoverable } -> recoverable

let to_json = function
  | ApiError r | RuntimeError r ->
    error_record_to_yojson r

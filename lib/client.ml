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

open Lwt.Infix

module Constants = struct
  let runtime_api_version = "2018-06-01"

  let api_content_type = "application/json"

  let api_error_content_type = "application/vnd.aws.lambda.error+json"

  let runtime_error_header = "Lambda-Runtime-Function-Error-Type"

  module RequestHeaders = struct
    let request_id = "Lambda-Runtime-Aws-Request-Id"

    let function_arn = "Lambda-Runtime-Invoked-Function-Arn"

    let trace_id = "Lambda-Runtime-Trace-Id"

    let deadline = "Lambda-Runtime-Deadline-Ms"

    let client_context = "Lambda-Runtime-Client-Context"

    let cognito_identity = "Lambda-Runtime-Cognito-Identity"
  end
end

type client_application =
  { (* The mobile app installation id *)
    installation_id : string
  ; (* The app title for the mobile app as registered with AWS' mobile
       services. *)
    app_title : string option [@default None]
  ; (* The version name of the application as registered with AWS' mobile
       services. *)
    app_version_name : string
  ; (* The app version code. *)
    app_version_code : string
  ; (* The package name for the mobile application invoking the function *)
    app_package_name : string
  }
[@@deriving of_yojson]

type client_context =
  { (* Information about the mobile application invoking the function. *)
    client : client_application
  ; (* Custom properties attached to the mobile event context. *)
    custom : Yojson.Safe.t
  ; (* Environment settings from the mobile client. *)
    env : Yojson.Safe.t
  }
[@@deriving of_yojson]

(* Cognito identity information sent with the event *)
type cognito_identity =
  { (* The unique identity id for the Cognito credentials invoking the
       function. *)
    identity_id : string
  ; (* The identity pool id the caller is "registered" with. *)
    identity_pool_id : string
  }
[@@deriving of_yojson]

type event_context =
  { (* The ARN of the Lambda function being invoked. *)
    invoked_function_arn : string
  ; (* The AWS request ID generated by the Lambda service. *)
    aws_request_id : string
  ; (* The X-Ray trace ID for the current invocation. *)
    xray_trace_id : string option [@default None]
  ; (* The execution deadline for the current invocation in milliseconds. *)
    deadline : int64
  ; (* The client context object sent by the AWS mobile SDK. This field is
       empty unless the function is invoked using an AWS mobile SDK. *)
    client_context : client_context option
  ; (* The Cognito identity that invoked the function. This field is empty
       unless the invocation request to the Lambda APIs was made using AWS
       credentials issues by Amazon Cognito Identity Pools. *)
    identity : cognito_identity option
  }

type t =
  { endpoint : string
  ; host : string
  ; connection : Httpaf_lwt_unix.Client.t
  }

let make endpoint =
  let uri = Uri.of_string (Format.asprintf "http://%s" endpoint) in
  let host = Uri.host_with_default uri in
  let port =
    match Uri.port uri with None -> "80" | Some p -> string_of_int p
  in
  Lwt_unix.getaddrinfo host port [ Unix.(AI_FAMILY PF_INET) ]
  >>= fun addresses ->
  let socket = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Lwt_unix.connect socket (List.hd addresses).Unix.ai_addr >|= fun () ->
  let connection = Httpaf_lwt_unix.Client.create_connection socket in
  { endpoint; connection; host }

let send_request
    { host; connection; _ }
    ?(meth = `GET)
    ?(additional_headers = [])
    ?body
    path
  =
  let open Httpaf in
  let open Httpaf_lwt_unix in
  let response_handler notify_response_received response response_body =
    Lwt.wakeup_later notify_response_received (Ok (response, response_body))
  in
  let error_handler notify_response_received error =
    Lwt.wakeup_later notify_response_received (Error error)
  in
  let content_length =
    match body with
    | None ->
      "0"
    | Some body ->
      string_of_int (String.length body)
  in
  let request_headers =
    Request.create
      meth
      path
      ~headers:
        (Headers.of_list
           (("Host", host)
           :: ("Content-Length", content_length)
           :: additional_headers))
  in
  let response_received, notify_response_received = Lwt.wait () in
  let response_handler = response_handler notify_response_received in
  let error_handler = error_handler notify_response_received in
  let request_body =
    Client.request connection request_headers ~error_handler ~response_handler
  in
  (match body with
  | Some body ->
    Body.write_string request_body body
  | None ->
    ());
  Body.flush request_body (fun () -> Body.close_writer request_body);
  response_received

let read_response response_body =
  let buf = Buffer.create 1024 in
  let body_read, notify_body_read = Lwt.wait () in
  let rec read_fn () =
    Httpaf.Body.schedule_read
      response_body
      ~on_eof:(fun () ->
        Lwt.wakeup_later notify_body_read (Buffer.contents buf))
      ~on_read:(fun response_fragment ~off ~len ->
        let response_fragment_bytes = Bytes.create len in
        Lwt_bytes.blit_to_bytes
          response_fragment
          off
          response_fragment_bytes
          0
          len;
        Buffer.add_bytes buf response_fragment_bytes;
        read_fn ())
  in
  read_fn ();
  body_read

let make_runtime_post_request client path output =
  let body = Yojson.Safe.to_string output in
  send_request
    client
    ~meth:`POST
    ~additional_headers:[ "Content-Type", Constants.api_content_type ]
    ~body
    path

let event_response client request_id output =
  let open Httpaf in
  let path =
    Format.asprintf
      "/%s/runtime/invocation/%s/response"
      Constants.runtime_api_version
      request_id
  in
  make_runtime_post_request client path output >>= function
  | Ok ({ Response.status; _ }, _) ->
    if not (Status.is_successful status) then
      let error =
        Errors.make_api_error
          ~recoverable:false
          (Printf.sprintf
             "Error %d while sending response"
             (Status.to_code status))
      in
      Lwt_result.fail error
    else
      Lwt_result.return ()
  | Error _ ->
    let err =
      Errors.make_api_error
        ~recoverable:false
        (Printf.sprintf
           "Error when calling runtime API for request %s"
           request_id)
    in
    Lwt_result.fail err

let make_runtime_error_request connection path error =
  let body = Errors.to_lambda_error error |> Yojson.Safe.to_string in
  send_request
    connection
    ~meth:`POST
    ~additional_headers:
      [ "Content-Type", Constants.api_error_content_type
      ; Constants.runtime_error_header, "RuntimeError"
      ]
    ~body
    path

let event_error client request_id err =
  let open Httpaf in
  let path =
    Format.asprintf
      "/%s/runtime/invocation/%s/error"
      Constants.runtime_api_version
      request_id
  in
  make_runtime_error_request client path err >>= function
  | Ok ({ Response.status; _ }, _) ->
    if not (Status.is_successful status) then
      let error =
        Errors.make_api_error
          ~recoverable:true
          (Printf.sprintf
             "Error %d while sending response"
             (Status.to_code status))
      in
      Lwt_result.fail error
    else
      Lwt_result.return ()
  | Error _ ->
    let err =
      Errors.make_api_error
        ~recoverable:true
        (Printf.sprintf
           "Error when calling runtime API for request %s"
           request_id)
    in
    Lwt_result.fail err

let fail_init client err =
  let path =
    Format.asprintf "/%s/runtime/init/error" Constants.runtime_api_version
  in
  make_runtime_error_request client path err >>= function
  | Ok _ ->
    Lwt_result.return ()
  (* TODO: do we wanna "failwith" or just raise and then have a generic
     `Lwt.catch` that will `failwith`? *)
  | Error _ ->
    failwith "Error while sending init failed message"

let get_event_context headers =
  let open Httpaf in
  let report_error header =
    let err =
      Errors.make_api_error
        ~recoverable:true
        (Printf.sprintf "Missing %s header" header)
    in
    Error err
  in
  let open Constants in
  match Headers.get headers RequestHeaders.request_id with
  | None ->
    report_error RequestHeaders.request_id
  | Some aws_request_id ->
    (match Headers.get headers RequestHeaders.function_arn with
    | None ->
      report_error RequestHeaders.function_arn
    | Some invoked_function_arn ->
      (match Headers.get headers RequestHeaders.deadline with
      | None ->
        report_error RequestHeaders.deadline
      | Some deadline_str ->
        let deadline = Int64.of_string deadline_str in
        let client_context =
          match Headers.get headers RequestHeaders.client_context with
          | None ->
            None
          | Some ctx_json_str ->
            let ctx_json = Yojson.Safe.from_string ctx_json_str in
            (match client_context_of_yojson ctx_json with
            | Error _ ->
              None
            | Ok client_ctx ->
              Some client_ctx)
        in
        let identity =
          match Headers.get headers RequestHeaders.cognito_identity with
          | None ->
            None
          | Some cognito_json_str ->
            let cognito_json = Yojson.Safe.from_string cognito_json_str in
            (match cognito_identity_of_yojson cognito_json with
            | Error _ ->
              None
            | Ok cognito_identity ->
              Some cognito_identity)
        in
        let ctx =
          { aws_request_id
          ; invoked_function_arn
          ; xray_trace_id = Headers.get headers RequestHeaders.trace_id
          ; deadline
          ; client_context
          ; identity
          }
        in
        Ok ctx))

let next_event client =
  let open Httpaf in
  let path =
    Format.asprintf "/%s/runtime/invocation/next" Constants.runtime_api_version
  in
  Logs_lwt.info (fun m -> m "Polling for next event. Path: %s\n" path)
  >>= fun () ->
  send_request client path >>= function
  | Ok ({ Response.status; headers; _ }, body) ->
    let code = Status.to_code status in
    if Status.is_client_error status then
      Logs_lwt.err (fun m ->
          m
            "Runtime API returned client error when polling for new events %d\n"
            code)
      >>= fun () ->
      let err =
        Errors.make_api_error
          ~recoverable:true
          (Printf.sprintf "Error %d when polling for events" code)
      in
      Lwt_result.fail err
    else if Status.is_server_error status then
      Logs_lwt.err (fun m ->
          m
            "Runtime API returned server error when polling for new events %d\n"
            code)
      >>= fun () ->
      let err =
        Errors.make_api_error
          ~recoverable:false
          "Server error when polling for new events"
      in
      Lwt_result.fail err
    else (
      match get_event_context headers with
      | Error err ->
        Logs_lwt.err (fun m ->
            m "Failed to get event context: %s\n" (Errors.message err))
        >>= fun () ->
        Lwt_result.fail err
      | Ok ctx ->
        read_response body >>= fun body_str ->
        Lwt_result.return (body_str, ctx))
  | Error _ ->
    let err =
      Errors.make_api_error
        ~recoverable:false
        "Server error when polling for new events"
    in
    Lwt_result.fail err

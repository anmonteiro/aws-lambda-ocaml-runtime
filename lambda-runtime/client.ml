open Lwt.Infix

[@@@ocaml.warning "-39"]

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

type client_application = {
    (* The mobile app installation id *)
    installation_id: string [@key "installationId"];
    (* The app title for the mobile app as registered with AWS' mobile services. *)
    app_title: string [@key "appTitle"];
    (* The version name of the application as registered with AWS' mobile services. *)
    app_version_name: string [@key "appVersionName"];
    (* The app version code. *)
    app_version_code: string [@key "appVersionCode"];
    (* The package name for the mobile application invoking the function *)
    app_package_name: string [@key "appPackageName"];
}
[@@deriving yojson]

type client_context = {
  (* Information about the mobile application invoking the function. *)
  client: client_application;
  (* Custom properties attached to the mobile event context. *)
  custom: Yojson.Safe.json;
  (* Environment settings from the mobile client. *)
  environment: Yojson.Safe.json;
}
[@@deriving yojson]

(* Cognito identity information sent with the event *)
type cognito_identity = {
  (* The unique identity id for the Cognito credentials invoking the function. *)
  identity_id: string;
  (* The identity pool id the caller is "registered" with. *)
  identity_pool_id: string;
}
[@@deriving yojson]

type event_context = {
  (* The ARN of the Lambda function being invoked. *)
  invoked_function_arn: string;
  (* The AWS request ID generated by the Lambda service. *)
  aws_request_id: string;
  (* The X-Ray trace ID for the current invocation. *)
  xray_trace_id: string;
  (* The execution deadline for the current invocation in milliseconds. *)
  deadline: int64;
  (* The client context object sent by the AWS mobile SDK. This field is
  empty unless the function is invoked using an AWS mobile SDK. *)
  client_context: client_context option;
  (* The Cognito identity that invoked the function. This field is empty
  unless the invocation request to the Lambda APIs was made using AWS
  credentials issues by Amazon Cognito Identity Pools. *)
  identity: cognito_identity option;
}
[@@deriving yojson]

type t = string

let make endpoint =
  endpoint

let send_request ?(meth=`GET) ?(additional_headers=[]) ?body uri =
  let open Httpaf in
  let open Httpaf_lwt in
  let response_handler notify_response_received response response_body =
    Lwt.wakeup_later notify_response_received (Ok (response, response_body))
  in
  let error_handler notify_response_received error =
    Lwt.wakeup_later notify_response_received (Error error)
  in
  let host = Uri.host_with_default uri in
  let port = match Uri.port uri with
  | None -> "80"
  | Some p -> string_of_int p
  in
  Lwt_unix.getaddrinfo host port [Unix.(AI_FAMILY PF_INET)]
    >>= fun addresses ->
    let socket = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    Lwt_unix.connect socket (List.hd addresses).Unix.ai_addr
    >>= fun () ->

    let content_length = match body with
    | None -> "0"
    | Some body -> string_of_int (String.length body)
    in
    let request_headers = Request.create
      meth
      (Uri.path_and_query uri)
      ~headers:(Headers.of_list ([
        "Host", host;
        "Content-Length", content_length;
      ] @ additional_headers))
    in

    let response_received, notify_response_received = Lwt.wait () in
    let response_handler = response_handler notify_response_received in
    let error_handler = error_handler notify_response_received in

    let request_body =
      Client.request
        socket
        request_headers
        ~error_handler
        ~response_handler
    in
    begin match body with
    | Some body -> Body.write_string request_body body
    | None -> ()
    end;
    Body.close_writer request_body;
    response_received

let read_response response_body =
  let buf = Buffer.create 1024 in
  let body_read, notify_body_read = Lwt.wait () in
  let rec read_fn () =
    Httpaf.Body.schedule_read
      response_body
      ~on_eof:(fun () -> Lwt.wakeup_later notify_body_read (Buffer.contents buf))
      ~on_read:(fun response_fragment ~off ~len ->
        let response_fragment_bytes = Bytes.create len in
        Lwt_bytes.blit_to_bytes
          response_fragment off
          response_fragment_bytes 0
          len;
        Buffer.add_bytes buf response_fragment_bytes;
        read_fn ())
  in
  read_fn ();
  body_read

let make_runtime_post_request uri output =
  let body = Yojson.Safe.to_string output in
  send_request
    ~meth:`POST
    ~additional_headers:["Content-Type", Constants.api_content_type]
    ~body
    uri

let event_response client request_id output =
  let open Httpaf in
  let uri = Uri.of_string
    (Printf.sprintf
      "http://%s/%s/runtime/invocation/%s/response"
      client Constants.runtime_api_version request_id)
  in
  make_runtime_post_request uri output >>= function
  | Ok ({ Response.status }, _) ->
    if not (Status.is_successful status) then
      let error = Errors.make_api_error
        ~recoverable:false
        (Printf.sprintf "Error %d while sending response" (Status.to_code status))
      in
      Lwt_result.fail error
    else
      Lwt_result.return ()
  | Error _ ->
    let err = Errors.make_api_error
      ~recoverable:false
      (Printf.sprintf "Error when calling runtime API for request %s" request_id)
    in
    Lwt_result.fail err

let make_runtime_error_request uri error =
  let body = Errors.to_lambda_error error |> Yojson.Safe.to_string in
  send_request
    ~meth:`POST
    ~additional_headers:[
      "Content-Type", Constants.api_error_content_type;
      Constants.runtime_error_header, "RuntimeError"
    ]
    ~body
    uri

let event_error client request_id err =
  let open Httpaf in
  let uri = Uri.of_string
    (Printf.sprintf
      "http://%s/%s/runtime/invocation/%s/error"
      client Constants.runtime_api_version request_id)
  in
  make_runtime_error_request uri err >>= function
  | Ok ({ Response.status }, _) ->
    if not (Status.is_successful status) then
      let error = Errors.make_api_error
        ~recoverable:true
        (Printf.sprintf "Error %d while sending response" (Status.to_code status))
      in
      Lwt_result.fail error
    else
      Lwt_result.return ()
  | Error _ ->
    let err = Errors.make_api_error
      ~recoverable:true
      (Printf.sprintf "Error when calling runtime API for request %s" request_id)
    in
    Lwt_result.fail err

let fail_init client err =
  let uri = Uri.of_string
    (Printf.sprintf
      "http://%s/%s/runtime/init/error" client Constants.runtime_api_version)
  in
  make_runtime_error_request uri err >>= function
  | Ok _ -> Lwt_result.return ()
  (* TODO: do we wanna "failwith" or just raise and  then have a generic
  `Lwt.catch` that will `failwith`? *)
  | Error _ -> failwith "Error while sending init failed message"

let get_event_context headers =
  let open Httpaf in
  let report_error header =
    let err = Errors.make_api_error
      ~recoverable:true
      (Printf.sprintf "Missing %s header" header)
    in
    Error err
  in
  let open Constants in
  match Headers.get headers RequestHeaders.request_id with
  | None -> report_error RequestHeaders.request_id
  | Some aws_request_id ->
    begin match Headers.get headers RequestHeaders.function_arn with
    | None -> report_error RequestHeaders.function_arn
    | Some invoked_function_arn ->
      begin match Headers.get headers RequestHeaders.trace_id with
      | None -> report_error RequestHeaders.trace_id
      | Some xray_trace_id ->
        begin match Headers.get headers RequestHeaders.deadline with
        | None -> report_error RequestHeaders.deadline
        | Some deadline_str ->
          let deadline = Int64.of_string deadline_str in
          let client_context = match Headers.get headers RequestHeaders.client_context with
          | None -> None
          | Some ctx_json_str ->
            let ctx_json = Yojson.Safe.from_string ctx_json_str in
            begin match client_context_of_yojson ctx_json with
            | Error _ -> None
            | Ok client_ctx -> Some client_ctx
            end
          in
          let identity = match Headers.get headers RequestHeaders.cognito_identity with
          | None -> None
          | Some cognito_json_str ->
            let cognito_json = Yojson.Safe.from_string cognito_json_str in
            begin match cognito_identity_of_yojson cognito_json with
            | Error _ -> None
            | Ok cognito_identity -> Some cognito_identity
            end
          in
          let ctx = {
            aws_request_id;
            invoked_function_arn;
            xray_trace_id;
            deadline;
            client_context;
            identity;
          }
          in Ok ctx
        end
      end
    end

let next_event client =
  let open Httpaf in
  let uri = Uri.of_string
    (Printf.sprintf "http://%s/%s/runtime/invocation/next" client Constants.runtime_api_version)
  in
  Logs_lwt.info (fun m ->
    m "Polling for next event. Uri: %s\n" (Uri.to_string uri)) >>= fun () ->
  send_request uri >>= function
  | Ok ({ Response.status; headers }, body) ->
    let code = Status.to_code status in
    if Status.is_client_error status then begin
      Logs_lwt.err (fun m ->
        m "Runtime API returned client error when polling for new events %d\n" code) >>= fun () ->
      let err = Errors.make_api_error
        ~recoverable:true
        (Printf.sprintf "Error %d when polling for events" code)
      in
      Lwt_result.fail err
    end else if Status.is_server_error status then begin
      Logs_lwt.err (fun m ->
        m "Runtime API returned server error when polling for new events %d\n" code) >>= fun () ->
      let err = Errors.make_api_error
        ~recoverable:false
        "Server error when polling for new events"
      in
      Lwt_result.fail err
    end else begin
      match get_event_context headers with
      | Error err ->
        Logs_lwt.err (fun m ->
          m "Failed to get event context: %s\n" (Errors.message err)) >>= fun () ->
        Lwt_result.fail err
      | Ok ctx ->
        read_response body >>= fun body_str ->
        Lwt_result.return (body_str, ctx)
      end
  | Error _ ->
    let err = Errors.make_api_error
      ~recoverable:false
      "Server error when polling for new events"
    in
    Lwt_result.fail err
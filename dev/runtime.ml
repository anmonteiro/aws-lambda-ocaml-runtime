open Lwt.Infix

module type DevEvent = sig
  type t

  val of_yojson : Yojson.Safe.t -> (t, string) result

  val of_piaf : Unix.sockaddr Piaf.Server.ctx -> (t, string) Lwt_result.t
end

module type DevResponse = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val to_piaf : t -> Piaf.Response.t
end

module Make
  (Event : DevEvent)
  (Response : DevResponse) = struct
  let make_mocked_context () =
    (* TODO: add proper values for this *)
    Lambda_runtime.Context.{ memory_limit_in_mb = 128
                           ; function_name = "hello"
                           ; function_version = "$LATEST"
                           ; invoked_function_arn = ""
                           ; aws_request_id = ""
                           ; xray_trace_id = None
                           ; log_stream_name = ""
                           ; log_group_name = ""
                           ; client_context = None
                           ; identity = None
                           ; deadline = 0L }

  let invoke_locally ~lift handler event =
    let context = make_mocked_context () in
    lift (handler event context)

  let run_locally ~lift handler =
    let event =
      if Array.length Sys.argv > 1 then
        Lwt_io.(open_file ~mode:Input Sys.argv.(2))
        >>= Lwt_io.read
        >|= Yojson.Safe.from_string
      else
        Lwt.return `Null
    in
    event
    >|= Event.of_yojson
    >|= (function
         | Ok event -> event
         (* TODO: This shouldnt fail, it should show a better error message instead. (stack trace?) *)
         | Error msg -> failwith msg)
    >>= invoke_locally ~lift handler
    >|= (function
         | Ok response ->
            response
            |> Response.to_yojson
            |> Yojson.Safe.to_string
         | Error msg ->
            "Error: " ^ msg)
    >|= print_endline

  let start_locally ~lift handler =
    let server_handler ctx =
      let event =
        Event.of_piaf ctx
        (* TODO: Shouldn't fail, return 400 message instead. *)
        >|= (function Ok event -> event | Error msg -> failwith msg)
      in
      let response =
        event
        >>= invoke_locally ~lift handler
      in
      response
      >|= (function
           | Ok response ->
              Response.to_piaf response
           | Error body ->
              Piaf.Response.of_string ~body `Internal_server_error)
    in
    Lwt.async (fun () ->
        let address = Unix.(ADDR_INET (inet_addr_loopback, 5000)) in
        Lwt_io.establish_server_with_client_socket
          address
          (Piaf.Server.create server_handler)
        >|= fun _server ->
        print_endline "Server started at: http://127.0.0.1:5000"
      );
    let forever, _ = Lwt.wait () in
    forever

  let start_lambda ~lift handler =
    let p =
      match Array.length Sys.argv with
      | 1 -> start_locally ~lift handler
      | 2 when Sys.argv.(1) = "invoke" ->
         run_locally ~lift handler
      | 2 when Sys.argv.(1) = "start-api" ->
         start_locally ~lift handler
      | 3 when Sys.argv.(1) = "invoke" ->
         run_locally ~lift handler
      | _ ->
         failwith "Invalid command line arguments!"
    in
    Lwt_main.run p

  let lambda handler =
    start_lambda ~lift:Lwt.return handler
end

let my_handler { Now_lambda.body; host; _ } _context =
  let body =
    match body with
    | Some body ->
      body
    | None ->
      Printf.sprintf "Didn't get an HTTP body from %s" host
  in
  Ok
    Now_lambda.
      { status_code = 200
      ; headers =
          Lambda_runtime.StringMap.(
            empty |> add "content-type" "application/json")
      ; body
      ; encoding = None
      }

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let () =
  setup_log (Some Logs.Debug);
  Now_lambda.lambda my_handler

let my_handler evt _context =
  match Yojson.Safe.Util.member "body" evt with
  | `String body ->
    Ok
      (`Assoc
        [ "statusCode", `Int 200
        ; "body", `String (Yojson.Safe.prettify body)
        ; "headers", `Assoc []
        ])
  | _ ->
    Error "Body wasn't string"

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let () =
  setup_log (Some Logs.Debug);
  Lambda_runtime.Json.lambda my_handler

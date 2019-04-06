let my_handler evt ctx =
  let ctx_json = Lambda_runtime.Context.to_yojson ctx in
  Ok
    (`Assoc
      [ "statusCode", `Int 200
      ; "headers", `Assoc []
      ; "body", `String (Yojson.Safe.to_string (`List [ evt; ctx_json ]))
      ])

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let () =
  setup_log (Some Logs.Debug);
  Lambda_runtime.Json.lambda my_handler

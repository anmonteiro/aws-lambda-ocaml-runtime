open Lambda_runtime_private.Http

module StringMap = Map.Make(String)

let my_handler evt _context =
  Ok {
    status_code = 200;
    headers = StringMap.empty;
    body = API_gateway_request.to_yojson evt |> Yojson.Safe.to_string;
    is_base64_encoded= false
  }

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let () =
  setup_log (Some Logs.Debug);
  Lambda_runtime_private.Http.lambda my_handler

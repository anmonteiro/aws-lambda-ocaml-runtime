open Lambda_runtime
module StringMap = Map.Make (String)

let my_handler (evt : Http.api_gateway_proxy_request) _context =
  let body = match evt.Http.body with None -> "" | Some body -> body in
  Ok
    Http.
      { status_code = 200
      ; headers = StringMap.empty
      ; body
      ; is_base64_encoded = false
      }

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let () =
  setup_log (Some Logs.Debug);
  Http.lambda my_handler

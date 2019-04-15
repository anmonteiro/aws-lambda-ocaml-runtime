open Now

let my_handler reqd _context =
  let { Request.headers; _ } = Reqd.request reqd in
  let body = Reqd.request_body reqd in
  let host = Headers.get_exn headers "host" in
  let body =
    match body with
    | Some body ->
      body
    | None ->
      Printf.sprintf "Didn't get an HTTP body from %s" host
  in
  let response =
    Response.create
      ~headers:(Headers.of_list [ "Content-Type", "application/json" ])
      `OK
  in
  Ok (Reqd.respond_with_string reqd response body)

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let () =
  setup_log (Some Logs.Debug);
  Now.lambda my_handler

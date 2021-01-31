open Lwt.Syntax
open Vercel

let my_handler request _context =
  let { Request.headers; body; _ } = request in
  let host = Headers.get_exn headers "host" in
  let+ body = Piaf.Body.to_string body in
  let body = Result.get_ok body in
  let body =
    if String.length body > 0 then
      body
    else
      Format.asprintf "Didn't get an HTTP body from %s" host
  in
  let response =
    Response.of_string
      ~body
      ~headers:(Headers.of_list [ "Content-Type", "application/json" ])
      `OK
  in
  Ok response

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let () =
  setup_log (Some Logs.Debug);
  Vercel.io_lambda my_handler

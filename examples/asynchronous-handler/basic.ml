open Lwt.Infix

let my_handler evt _context =
  Logs_lwt.app (fun m -> m "Hello from the async handler") >>= fun () ->
  Lwt_result.return evt

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let () =
  setup_log (Some Logs.Debug);
  Lambda_runtime.Json.io_lambda my_handler

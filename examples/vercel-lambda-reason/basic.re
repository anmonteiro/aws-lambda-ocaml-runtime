open Lwt.Infix;
module Client = Piaf.Client.Oneshot;

let my_handler = (_request, _context) => {
  let uri =
    Uri.of_string(
      "http://api.giphy.com/v1/gifs/random?tag=cat&api_key=hamBGlVDz0XI5tYtxTuPgudCVhHSNX8q&limit=1",
    );
  Client.get(uri)
  >>= (
    fun
    | Ok(response) => {
        Piaf.Body.to_string(response.body)
        >>= (
          fun
          | Ok(body_str) => {
              open Yojson.Safe;
              let body_json = Yojson.Safe.from_string(body_str);
              let img_url =
                body_json
                |> Util.member("data")
                |> Util.member("images")
                |> Util.member("original")
                |> Util.member("url")
                |> Util.to_string;
              let body = Printf.sprintf("<img src=\"%s\">", img_url);
              let response =
                Piaf.Response.of_string(
                  ~body,
                  ~headers=
                    Piaf.Headers.of_list([("content-type", "text/html")]),
                  `OK,
                );
              Lwt.return_ok(response);
            }
          | Error(_) => Lwt.return(Error("Failed for some reason"))
        );
      }
    | Error(_) => Lwt.return(Error("Failed for some reason"))
  );
};

let setup_log = (~style_renderer=?, level) => {
  Fmt_tty.setup_std_outputs(~style_renderer?, ());
  Logs.set_level(level);
  Logs.set_reporter(Logs_fmt.reporter());
  ();
};

let () = {
  setup_log(Some(Logs.Debug));
  Vercel.io_lambda(my_handler);
};

module Client = Piaf.Client.Oneshot;

let my_handler = (_request, {Lambda_runtime.Context.sw, env, _}) => {
  let uri =
    Uri.of_string(
      "http://api.giphy.com/v1/gifs/random?tag=cat&api_key=hamBGlVDz0XI5tYtxTuPgudCVhHSNX8q&limit=1",
    );
  switch (Client.get(~sw, env, uri)) {
  | Ok(response) =>
    switch (Piaf.Body.to_string(response.body)) {
    | Ok(body_str) =>
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
          ~headers=Piaf.Headers.of_list([("content-type", "text/html")]),
          `OK,
        );
      Ok(response);
    | Error(_) => Error("Failed for some reason")
    }
  | Error(_) => Error("Failed for some reason")
  };
};

let setup_log = (~style_renderer=?, level) => {
  Fmt_tty.setup_std_outputs(~style_renderer?, ());
  Logs.set_level(level);
  Logs.set_reporter(Logs_fmt.reporter());
  ();
};

let () = {
  setup_log(Some(Logs.Debug));
  Vercel.lambda(my_handler);
};

open Lwt.Infix;

let send_request = (~meth=`GET, ~additional_headers=[], ~body=?, uri) => {
  open Httpaf;
  open Httpaf_lwt_unix;
  let response_handler = (notify_response_received, response, response_body) =>
    Lwt.wakeup_later(
      notify_response_received,
      Ok((response, response_body)),
    );

  let error_handler = (notify_response_received, error) =>
    Lwt.wakeup_later(notify_response_received, Error(error));

  let host = Uri.host_with_default(uri);
  let port =
    switch (Uri.port(uri)) {
    | None => "80"
    | Some(p) => string_of_int(p)
    };

  Lwt_unix.getaddrinfo(host, port, [Unix.(AI_FAMILY(PF_INET))])
  >>= (
    addresses => {
      let socket = Lwt_unix.socket(Unix.PF_INET, Unix.SOCK_STREAM, 0);
      Lwt_unix.connect(socket, List.hd(addresses).Unix.ai_addr)
      >>= (
        () => {
          Client.create_connection(socket)
          >>= (
            connection => {
              let content_length =
                switch (body) {
                | None => "0"
                | Some(body) => string_of_int(String.length(body))
                };

              let request_headers =
                Request.create(
                  meth,
                  Uri.path_and_query(uri),
                  ~headers=
                    Headers.of_list(
                      [("Host", host), ("Content-Length", content_length)]
                      @ additional_headers,
                    ),
                );

              let (response_received, notify_response_received) = Lwt.wait();
              let response_handler =
                response_handler(notify_response_received);
              let error_handler = error_handler(notify_response_received);

              let request_body =
                Client.request(
                  connection,
                  request_headers,
                  ~error_handler,
                  ~response_handler,
                );

              switch (body) {
              | Some(body) => Body.write_string(request_body, body)
              | None => ()
              };
              Body.flush(request_body, () => Body.close_writer(request_body));
              response_received;
            }
          );
        }
      );
    }
  );
};

let read_response = response_body => {
  let buf = Buffer.create(1024);
  let (body_read, notify_body_read) = Lwt.wait();
  let rec read_fn = () =>
    Httpaf.Body.schedule_read(
      response_body,
      ~on_eof=() => Lwt.wakeup_later(notify_body_read, Buffer.contents(buf)),
      ~on_read=
        (response_fragment, ~off, ~len) => {
          let response_fragment_bytes = Bytes.create(len);
          Lwt_bytes.blit_to_bytes(
            response_fragment,
            off,
            response_fragment_bytes,
            0,
            len,
          );
          Buffer.add_bytes(buf, response_fragment_bytes);
          read_fn();
        },
    );

  read_fn();
  body_read;
};

let my_handler = (reqd, _context) => {
  let uri =
    Uri.of_string(
      "http://api.giphy.com/v1/gifs/random?tag=cat&api_key=hamBGlVDz0XI5tYtxTuPgudCVhHSNX8q&limit=1",
    );
  send_request(uri)
  >>= (
    fun
    | Ok((_response, body)) =>
      read_response(body)
      >>= (
        body_str => {
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
            Httpaf.Response.create(
              ~headers=
                Httpaf.Headers.of_list([("content-type", "text/html")]),
              `OK,
            );
          Lwt.return(Now.Reqd.respond_with_string(reqd, response, body));
        }
      )
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
  Now.io_lambda(my_handler);
};

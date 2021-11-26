module DevEvent = struct
  type t = Yojson.Safe.t [@@deriving of_yojson]

  let of_piaf (ctx: 'a Piaf.Server.ctx) =
    let event =
      let open Lwt_result.Infix in
      Piaf.Body.to_string ctx.request.body
      >|= (fun body -> if body = String.empty then None else Some body)
      (* TODO: failing to parse body should respond with 400 error and not 500 *)
      >|= Option.map Yojson.Safe.from_string
      >|= Option.value ~default:`Null
    in
    Lwt_result.map_err Piaf.Error.to_string event
end

module DevResponse = struct
  type t = Yojson.Safe.t [@@deriving to_yojson]

  let to_yojson t = to_yojson t

  let content_json headers =
    Piaf.Headers.add headers "content-type" "application/json"

  let to_piaf response =
    let body = Yojson.Safe.to_string response in
    Piaf.Response.of_string
                     ~headers:(content_json Piaf.Headers.empty)
                     ~body
                     `OK
end

include Runtime.Make (DevEvent) (DevResponse)

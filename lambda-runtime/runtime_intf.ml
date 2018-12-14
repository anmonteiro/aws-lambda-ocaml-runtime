module type LambdaIO = sig
  type t

  val of_yojson: Yojson.Safe.json -> (t, string) result
  val to_yojson: t -> Yojson.Safe.json
end

module type LambdaRuntime = sig
  type event
  type response

  val lambda: (event -> Context.t -> (response, string) result) -> unit

  val io_lambda: (event -> Context.t -> (response, string) result Lwt.t) -> unit
end
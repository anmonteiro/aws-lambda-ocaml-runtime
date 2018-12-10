module type LambdaRuntime = sig
  open Lambda_runtime_private
  type event
  type response

  val lambda: (event -> Context.t -> (response, string) result) -> unit

  val io_lambda: (event -> Context.t -> (response, string) result Lwt.t) -> unit
end
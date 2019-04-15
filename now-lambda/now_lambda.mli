open Lambda_runtime

(* To keep module equality. See e.g.:
 * https://stackoverflow.com/a/37307124/3417023 *)
module Headers : module type of struct
  include Httpaf.Headers
end

module Request : module type of struct
  include Httpaf.Request
end

module Response : module type of struct
  include Httpaf.Response
end

module Reqd : sig
  type t

  type response

  val request : t -> Httpaf.Request.t

  val request_body : t -> string option

  val response : t -> Httpaf.Response.t option

  val response_exn : t -> Httpaf.Response.t

  val respond_with_string : t -> Httpaf.Response.t -> string -> response

  val respond_with_bigstring
    :  t
    -> Httpaf.Response.t
    -> ?off:int
    -> ?len:int
    -> Bigstringaf.t
    -> response
end

include
  Runtime_intf.LambdaRuntime
  with type event = Reqd.t
   and type response = Reqd.response

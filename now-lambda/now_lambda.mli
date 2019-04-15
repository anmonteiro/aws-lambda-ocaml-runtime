open Lambda_runtime

type handler_response

include
  Runtime_intf.LambdaRuntime
  with type event = Httpaf.Request.t * string option
   and type response = handler_response

val respond_with_string : Httpaf.Response.t -> string -> handler_response

val respond_with_bigstring
  :  Httpaf.Response.t
  -> ?off:int
  -> ?len:int
  -> Bigstringaf.t
  -> handler_response

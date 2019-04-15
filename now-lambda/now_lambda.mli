open Lambda_runtime

include
  Runtime_intf.LambdaRuntime
  with type event = Httpaf.Request.t * string option
   and type response = Httpaf.Response.t * string

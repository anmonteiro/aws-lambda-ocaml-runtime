include Lambda_runtime.Make (Reqd) (Response)

(* Proxy to http/af for Headers, Request and Response for convenience *)
module Headers = Httpaf.Headers
module Request = Httpaf.Request
module Response = Httpaf.Response

(* Request descriptor for Now.sh requests *)
module Reqd = Reqd

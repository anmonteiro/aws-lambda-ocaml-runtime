module Client = Client
module Context = Context
module Errors = Errors
module Config = Config
module Util = Util
module StringMap = Util.StringMap

module Id = struct
  [@@@ocaml.warning "-39"]
  type t = Yojson.Safe.json
  [@@deriving yojson]
end

module Make = Runtime.Make

module Json = Runtime.Make (Id) (Id)
module Http = Lambda_http

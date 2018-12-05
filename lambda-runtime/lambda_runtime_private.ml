module Client = Client
module Context = Context
module Errors = Errors
module Config = Config

module Id = struct
  type t = Yojson.Safe.json
  [@@deriving yojson]
end

module Runtime = Runtime.Make (Id) (Id)
module Http = Lambda_http

let start_with_runtime_client handler function_config client =
  let runtime = Runtime.make ~handler ~max_retries:3 ~settings:function_config client
  in Runtime.start runtime

let start handler =
  match Config.get_runtime_api_endpoint() with
  | Ok endpoint ->
    begin match Config.get_function_settings() with
    | Ok function_config ->
      let client = Client.make(endpoint) in
       start_with_runtime_client handler function_config client
    | Error msg -> failwith msg
    end
  | Error msg -> failwith msg

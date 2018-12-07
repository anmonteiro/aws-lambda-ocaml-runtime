module Client = Client
module Context = Context
module Errors = Errors
module Config = Config

module Id = struct
  [@@@ocaml.warning "-39"]
  type t = Yojson.Safe.json
  [@@deriving yojson]
end

module Runtime = Runtime.Make (Id) (Id)
module Http = Lambda_http

let id: 'a. 'a -> 'a = fun x -> x

let start_with_runtime_client ~lift handler function_config client =
  let runtime = Runtime.make
    ~max_retries:3
    ~settings:function_config client
    ~lift
    ~handler
  in
  Lwt_main.run (Runtime.start runtime)

let start handler =
  match Config.get_runtime_api_endpoint() with
  | Ok endpoint ->
    begin match Config.get_function_settings() with
    | Ok function_config ->
      let client = Client.make(endpoint) in
       start_with_runtime_client ~lift:Lwt.return handler function_config client
    | Error msg -> failwith msg
    end
  | Error msg -> failwith msg

let io_start handler =
  match Config.get_runtime_api_endpoint() with
  | Ok endpoint ->
    begin match Config.get_function_settings() with
    | Ok function_config ->
      let client = Client.make(endpoint) in
       start_with_runtime_client ~lift:id handler function_config client
    | Error msg -> failwith msg
    end
  | Error msg -> failwith msg
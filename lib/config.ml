open Util

type function_settings =
  { function_name : string
  ; memory_size : int
  ; version : string
  ; log_stream : string
  ; log_group : string
  }

module Env_vars = struct
  let runtime_endpoint_var = "AWS_LAMBDA_RUNTIME_API"

  let lambda_function_name = "AWS_LAMBDA_FUNCTION_NAME"

  let lambda_function_version = "AWS_LAMBDA_FUNCTION_VERSION"

  let lambda_function_memory_size = "AWS_LAMBDA_FUNCTION_MEMORY_SIZE"

  let lambda_log_stream_name = "AWS_LAMBDA_LOG_STREAM_NAME"

  let lambda_log_group_name = "AWS_LAMBDA_LOG_GROUP_NAME"
end

let env =
  let env_lst = Array.to_list (Unix.environment ()) in
  List.fold_left
    (fun m var ->
      match String.split_on_char '=' var with
      | k :: v :: _ ->
        StringMap.add k v m
      | _ ->
        m)
    StringMap.empty
    env_lst

let get_runtime_api_endpoint () =
  let var = Env_vars.runtime_endpoint_var in
  match StringMap.find_opt var env with
  | Some v ->
    Ok v
  | None ->
    Error (Printf.sprintf "Could not find runtime API env var: %s" var)

let get_function_settings ?(env = env) () =
  let get_env_vars () =
    let function_name = StringMap.find_opt Env_vars.lambda_function_name env in
    let version = StringMap.find_opt Env_vars.lambda_function_version env in
    let memory_str =
      StringMap.find_opt Env_vars.lambda_function_memory_size env
    in
    let log_stream = StringMap.find_opt Env_vars.lambda_log_stream_name env in
    let log_group = StringMap.find_opt Env_vars.lambda_log_group_name env in
    function_name, version, memory_str, log_stream, log_group
  in
  match get_env_vars () with
  | ( Some function_name
    , Some version
    , Some memory_str
    , Some log_stream
    , Some log_group ) ->
    (match int_of_string memory_str with
    | memory_size ->
      Ok { function_name; memory_size; version; log_stream; log_group }
    | exception Failure _ ->
      Error
        (Printf.sprintf
           "Memory value from environment is not an int: %s"
           memory_str))
  | _ ->
    Error
      "Could not find runtime API environment variables to determine function \
       settings."

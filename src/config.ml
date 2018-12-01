open Util
(*
  LAMBDA_TASK_ROOT,
  _HANDLER,
  AWS_LAMBDA_RUNTIME_API, *)

type function_settings = {
  function_name: string;
  memory_size: int;
  version: string;
  log_stream: string;
  log_group: string;
}

let env =
  let env_lst = Array.to_list (Unix.environment ()) in
  List.fold_left (fun m var ->
    match String.split_on_char '=' var with
    | k::v::_ -> StringMap.add k v m
    | _ -> m
  ) (StringMap.empty) env_lst

let get_runtime_api_endpoint () =
  let var = "AWS_LAMBDA_RUNTIME_API" in
  match StringMap.find_opt var env with
  | Some v -> Ok v
  | None -> Error (Printf.sprintf "Could not find runtime API env var: %s" var)

let get_function_settings () =
  let get_env_vars () =
    let function_name = StringMap.find_opt "AWS_LAMBDA_FUNCTION_NAME" env in
    let version = StringMap.find_opt "AWS_LAMBDA_FUNCTION_VERSION" env in
    let memory_str = StringMap.find_opt "AWS_LAMBDA_FUNCTION_MEMORY_SIZE" env in
    let log_stream = StringMap.find_opt "AWS_LAMBDA_LOG_STREAM_NAME" env in
    let log_group = StringMap.find_opt "AWS_LAMBDA_LOG_GROUP_NAME" env in
    function_name, version, memory_str, log_stream, log_group
  in
  match get_env_vars () with
  | Some function_name, Some version, Some memory_str, Some log_stream, Some log_group ->
    begin try
      let memory_size = int_of_string memory_str in
      Ok { function_name; memory_size; version; log_stream; log_group}
    with
    | _ -> Error (Printf.sprintf "Memory value from environment is not an int: %s" memory_str)
    end
  | _ -> Error "Could not find runtime API environment variables to determine function settings."

  (* let vars = [
    "AWS_LAMBDA_FUNCTION_NAME";
    "AWS_LAMBDA_FUNCTION_VERSION";
    "AWS_LAMBDA_FUNCTION_MEMORY_SIZE";
    "AWS_LAMBDA_LOG_GROUP_NAME";
    "AWS_LAMBDA_LOG_STREAM_NAME"
  ]
  in
  match List.map (fun var -> ) vars with
  | (Some function_name)::(Some function_version)::  -> Ok v
  | None -> Error (Printf.sprintf "Could not find runtime API env var: %s" var) *)


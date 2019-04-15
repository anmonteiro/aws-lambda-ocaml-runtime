(*----------------------------------------------------------------------------
 *  Copyright (c) 2018 António Nuno Monteiro
 *
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *  this list of conditions and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *
 *  3. Neither the name of the copyright holder nor the names of its
 *  contributors may be used to endorse or promote products derived from this
 *  software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *---------------------------------------------------------------------------*)

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

open Lambda_runtime
module Config = Lambda_runtime__.Config

let set_endpoint_env_var () =
  let open Config in
  Unix.putenv Env_vars.runtime_endpoint_var "localhost:8080";
  ()

let set_lambda_env_vars () =
  let open Config in
  Unix.putenv Env_vars.lambda_function_name "test_func";
  Unix.putenv Env_vars.lambda_function_version "$LATEST";
  Unix.putenv Env_vars.lambda_function_memory_size "128";
  Unix.putenv Env_vars.lambda_log_stream_name "LogStreamName";
  Unix.putenv Env_vars.lambda_log_group_name "LogGroup2";
  ()

let unset_env_vars () =
  let open Config in
  Unix.putenv Env_vars.runtime_endpoint_var "";
  Unix.putenv Env_vars.lambda_function_name "";
  Unix.putenv Env_vars.lambda_function_version "";
  Unix.putenv Env_vars.lambda_function_memory_size "";
  Unix.putenv Env_vars.lambda_log_stream_name "";
  Unix.putenv Env_vars.lambda_log_group_name "";
  ()

let get_env () =
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

let setup_and_run f () =
  unset_env_vars ();
  set_endpoint_env_var ();
  set_lambda_env_vars ();
  f ()

let suite =
  [ ( "config from env vars"
    , `Quick
    , setup_and_run @@ fun () ->
      match Config.get_function_settings ~env:(get_env ()) () with
      | Ok env_settings ->
        Alcotest.(
          check
            int
            "memory size read from env"
            128
            env_settings.Config.memory_size)
      | Error e ->
        Alcotest.fail e )
  ; ( "errors when vars are not set up"
    , `Quick
    , fun () ->
        unset_env_vars ();
        match Config.get_function_settings () with
        | Ok _env_settings ->
          Alcotest.fail "Expected env to not be setup"
        | Error _e ->
          Alcotest.(check pass "" 1 1) )
  ; ( "errors when runtime API endpoint is not set up"
    , `Quick
    , fun () ->
        unset_env_vars ();
        match Config.get_runtime_api_endpoint () with
        | Ok _endpoint ->
          Alcotest.fail "Expected env to not be setup"
        | Error _e ->
          Alcotest.(check pass "" 1 1) )
  ]

module Errors = Lambda_runtime__.Errors
module Config = Lambda_runtime__.Config
module Context = Lambda_runtime__.Context
module Client = Lambda_runtime__.Client

let id : 'a. 'a -> 'a = fun x -> x

let yojson =
  (module struct
    type t = Yojson.Safe.t

    let pp formatter t =
      Format.pp_print_text formatter (Yojson.Safe.pretty_to_string t)

    let equal = ( = )
  end : Alcotest.TESTABLE
    with type t = Yojson.Safe.t)

let error = ref false

module MockConfigProvider = struct
  let get_function_settings () =
    if !error then
      Error (Errors.make_runtime_error ~recoverable:false "Mock error")
    else
      Ok
        { Config.function_name = "MockFunction"
        ; memory_size = 128
        ; version = "$LATEST"
        ; log_stream = "LogStream"
        ; log_group = "LogGroup"
        }

  let get_runtime_api_endpoint () =
    if !error then
      Error (Errors.make_runtime_error ~recoverable:false "Mock error")
    else
      Ok "localhost:8080"

  let get_deadline secs =
    let now_ms = Unix.gettimeofday () *. 1000. in
    let deadline_f = now_ms +. (float_of_int secs *. 1000.) in
    Int64.of_float deadline_f

  let test_context deadline =
    { Context.memory_limit_in_mb = 128
    ; function_name = "test_func"
    ; function_version = "$LATEST"
    ; invoked_function_arn = "arn:aws:lambda"
    ; aws_request_id = "123"
    ; xray_trace_id = Some "123"
    ; log_stream_name = "logStream"
    ; log_group_name = "logGroup"
    ; client_context = None
    ; identity = None
    ; deadline = get_deadline deadline
    }
end

module type Runtime = sig
  type event

  type response

  type 'a runtime =
    { client : Client.t
    ; settings : Config.function_settings
    ; handler : event -> Context.t -> 'a
    ; max_retries : int
    ; lift : 'a -> (response, string) result Lwt.t
    }

  val make
    :  handler:(event -> Context.t -> 'a)
    -> max_retries:int
    -> settings:Config.function_settings
    -> lift:('a -> (response, string) result Lwt.t)
    -> Client.t
    -> 'a runtime

  val invoke
    :  'a runtime
    -> event
    -> Context.t
    -> (response, string) result Lwt.t
end

let test_runtime_generic
    (type event response)
    (module Runtime : Runtime
      with type event = event
       and type response = response)
    ~lift
    event
    handler
    test_fn
    ()
  =
  match MockConfigProvider.get_runtime_api_endpoint () with
  | Error _ ->
    Alcotest.fail "Could not get runtime endpoint"
  | Ok _runtime_api_endpoint ->
    (* Avoid creating a TCP connection for every test *)
    let client = Obj.magic () in
    (match MockConfigProvider.get_function_settings () with
    | Error _ ->
      Alcotest.fail "Could not load environment config"
    | Ok settings ->
      let runtime =
        Runtime.make ~handler ~lift ~max_retries:3 ~settings client
      in
      let output =
        Runtime.invoke runtime event (MockConfigProvider.test_context 10)
      in
      test_fn (Lwt_main.run output))

let read_all path =
  let file = open_in path in
  try really_input_string file (in_channel_length file) with
  | exn ->
    close_in file;
    raise exn

let test_fixture
    (module Request : Lambda_runtime__Runtime_intf.LambdaEvent) fixture ()
  =
  let fixture =
    read_all (Printf.sprintf "fixtures/%s.json" fixture)
    |> Yojson.Safe.from_string
  in
  match Request.of_yojson fixture with
  | Ok _req ->
    Alcotest.(check pass) "Parses correctly" true true
  | Error err ->
    Alcotest.fail err

let make_test_request
    (type a)
    (module Request : Lambda_runtime__Runtime_intf.LambdaEvent with type t = a)
    fixture
  =
  let fixture =
    read_all (Printf.sprintf "fixtures/%s.json" fixture)
    |> Yojson.Safe.from_string
  in
  match Request.of_yojson fixture with
  | Ok req ->
    req
  | Error err ->
    failwith
      (Printf.sprintf
         "Failed to parse API Gateway fixture into a mock request: %s\n"
         err)

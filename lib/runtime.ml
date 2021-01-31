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

open Lwt.Infix

module Make
    (Event : Runtime_intf.LambdaEvent)
    (Response : Runtime_intf.LambdaResponse) =
struct
  type 'a runtime =
    { client : Client.t
    ; settings : Config.function_settings
    ; handler : Event.t -> Context.t -> 'a
    ; max_retries : int
    ; lift : 'a -> (Response.t, string) result Lwt.t
    }

  let make ~handler ~max_retries ~settings ~lift client =
    { client; settings; max_retries; handler; lift }

  let rec get_next_event ?error runtime retries =
    match error with
    | Some err when retries > runtime.max_retries ->
      (match Errors.request_id err with
      | Some req_id ->
        Client.event_error runtime.client req_id err
      | None ->
        Client.fail_init runtime.client err)
      |> ignore;
      (* These errors are not recoverable. Either we can't communicate with the
       * runtime APIs or we cannot parse the event. panic to restart the
       * environment. *)
      failwith "Could not retrieve next event"
    | _ ->
      Client.next_event runtime.client >>= ( function
      | Ok (ev_data, invocation_ctx) ->
        (match ev_data |> Yojson.Safe.from_string |> Event.of_yojson with
        | Ok ev ->
          let handler_ctx =
            Context.make
              ~invoked_function_arn:invocation_ctx.invoked_function_arn
              ~aws_request_id:invocation_ctx.aws_request_id
              ~xray_trace_id:invocation_ctx.xray_trace_id
              ~client_context:invocation_ctx.client_context
              ~identity:invocation_ctx.identity
              ~deadline:invocation_ctx.deadline
              runtime.settings
          in
          Lwt.return (ev, handler_ctx)
        | Error err ->
          Logs_lwt.err (fun m -> m "Could not parse event to type: %s" err)
          >>= fun () ->
          let error =
            Errors.make_runtime_error
              ~recoverable:true
              ~request_id:invocation_ctx.aws_request_id
              (Printf.sprintf "Could not unserialize from JSON: %s" err)
          in
          get_next_event ~error runtime (retries + 1)
        | exception _ ->
          let error =
            Errors.make_runtime_error
              ~recoverable:false
              ~request_id:invocation_ctx.aws_request_id
              (Printf.sprintf "Could not parse event to type: %s" ev_data)
          in
          get_next_event ~error runtime (retries + 1))
      | Error e ->
        get_next_event ~error:e runtime (retries + 1) )

  let invoke { lift; handler; _ } event ctx =
    Lwt.catch
      (fun () -> lift (handler event ctx))
      (fun exn ->
        let backtrace = Printexc.get_backtrace () in
        let exn_str = Printexc.to_string exn in
        Lwt.return
          (Error (Printf.sprintf "Handler raised: %s\n%s" exn_str backtrace)))

  let rec start runtime =
    let open Lwt.Infix in
    get_next_event runtime 0 >>= fun (event, ctx) ->
    let request_id = ctx.aws_request_id in
    invoke runtime event ctx >>= function
    | Ok response ->
      Response.to_yojson response >>= fun response_json ->
      Client.event_response runtime.client request_id response_json
      >>= ( function
      | Ok _ ->
        start runtime
      | Error e ->
        if not (Errors.is_recoverable e) then
          Client.fail_init runtime.client e >>= fun _ ->
          Logs_lwt.err (fun m ->
              m "Could not send error response %s" (Errors.message e))
          >>= fun () -> failwith "Could not send error response"
        else
          start runtime )
    | Error msg ->
      let handler_error = Errors.make_handler_error msg in
      Client.event_error runtime.client request_id handler_error >>= ( function
      | Ok _ ->
        start runtime
      | Error e ->
        if not (Errors.is_recoverable e) then
          Logs_lwt.err (fun m ->
              m "Could not send error response %s" (Errors.message e))
          >>= fun () ->
          Client.fail_init runtime.client e >>= fun _ ->
          failwith "Could not send error response"
        else
          start runtime )

  let start_with_runtime_endpoint ~lift handler function_config endpoint =
    Client.make endpoint >>= function
    | Ok client ->
      let runtime =
        make ~max_retries:3 ~settings:function_config ~lift ~handler client
      in
      start runtime
    | Error e ->
      failwith
        (Format.asprintf "Could not start HTTP client: %a" Piaf.Error.pp_hum e)

  let start_lambda ~lift handler =
    match Config.get_runtime_api_endpoint () with
    | Ok endpoint ->
      (match Config.get_function_settings () with
      | Ok function_config ->
        let p =
          start_with_runtime_endpoint ~lift handler function_config endpoint
        in
        Lwt_main.run p
      | Error msg ->
        failwith msg)
    | Error msg ->
      failwith msg

  let lambda handler = start_lambda ~lift:Lwt.return handler

  let io_lambda handler = start_lambda ~lift:Util.id handler
end

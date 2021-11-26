
module DevEvent = struct
  type t = Lambda_runtime.Http.api_gateway_proxy_request

  let of_yojson _ =
    Error "Not implemented"

  let of_piaf (ctx: Unix.sockaddr Piaf.Server.ctx) =
    let open Lambda_runtime in
    let headers =
      ctx.request.headers
      |> Piaf.Headers.to_list
      |> List.to_seq
      |> StringMap.of_seq
    in
    let identity = Http.{ cognito_identity_pool_id = None
                        ; account_id = None
                        ; cognito_identity_id = None
                        ; caller = None
                        ; access_key = None
                        ; api_key = None
                        ; source_ip = "127.0.0.1" (* TODO: get the real value *)
                        ; cognito_authentication_type = None
                        ; cognito_authentication_provider = None
                        ; user_arn = None
                        ; user_agent = Piaf.Headers.get ctx.request.headers "user-agent"
                        ; user = None }
    in
    let uri = Piaf.Request.uri ctx.request in
    let request_id =
      Random.self_init ();
      Uuidm.to_string @@ Uuidm.v4_gen (Random.get_state ()) ()
    in
    let request_context = Http.{ account_id = "123456789012"
                               ; resource_id = "123456"
                               ; stage = "dev"
                               ; request_id
                               ; identity
                               ; resource_path = "/{proxy+}"
                               ; authorizer = None
                               ; http_method = Piaf.Method.to_string ctx.request.meth
                               ; protocol = Some (Piaf.Versions.HTTP.to_string ctx.request.version)
                               ; path = Some (Uri.path uri)
                               ; api_id = "1234567890" }
    in
    let body =
      Lwt_result.map_err Piaf.Error.to_string @@ Piaf.Body.to_string ctx.request.body
    in
    let query_string_parameters =
      Uri.query uri
      |> List.map (fun (key, values) ->
             (* TODO: Handle this properly, we need multivalue query strings *)
             match values with
             | [] -> (key, "")
             | [value] -> (key, value)
             | _ -> failwith "Multiple values not supported for query strings now")
      |> List.to_seq
      |> StringMap.of_seq
    in
    Lwt_result.map (fun body ->
        Http.{ resource = (Uri.path uri)
             ; path = request_context.resource_path
             ; http_method = request_context.http_method
             ; headers
             ; query_string_parameters
             ; path_parameters = StringMap.empty
             ; stage_variables = StringMap.empty
             ; request_context
             ; body = if body = String.empty then None else Some body
             ; is_base64_encoded = false })
      body
    
end

module DevResponse = struct
  type t = Lambda_runtime.Http.api_gateway_proxy_response

  let to_yojson _ = `Null

  let to_piaf response =
    let open Lambda_runtime in
    let headers =
      response.Http.headers
      |> StringMap.to_seq
      |> List.of_seq
      |> Piaf.Headers.of_list
    in
    (* TODO: Handle base64 *)
    assert (not response.Http.is_base64_encoded);

    let body = response.Http.body in
    Piaf.Response.of_string
      ~headers
      ~body
      (Piaf.Status.of_code response.Http.status_code)

end

include Runtime.Make (DevEvent) (DevResponse)

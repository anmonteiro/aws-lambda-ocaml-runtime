open Util

[@@@ocaml.warning "-39"]

(* APIGatewayRequestIdentity contains identity information for the request caller. *)
type api_gateway_request_identity = {
  cognito_identity_pool_id: string option [@key "cognitoIdentityPoolId"];
  account_id: string option [@key "accountId"];
  cognito_identity_id: string option [@key "cognitoIdentityId"];
  caller: string option;
  access_key: string option [@key "accessKey"] ;
  api_key: string option [@key "apiKey"] [@default None];
  source_ip: string [@key "sourceIp"];
  cognito_authentication_type: string option [@key "cognitoAuthenticationType"];
  cognito_authentication_provider: string option [@key "cognitoAuthenticationProvider"];
  user_arn: string option [@key "userArn"];
  user_agent: string option [@key "userAgent"];
  user: string option;
}
[@@deriving yojson]

(* APIGatewayProxyRequestContext contains the information to identify the AWS account and resources invoking the
Lambda function. It also includes Cognito identity information for the caller. *)
type api_gateway_proxy_request_context = {
  account_id: string [@key "accountId"];
  resource_id: string [@key "resourceId"];
  stage: string;
  request_id: string [@key "requestId"];
  identity: api_gateway_request_identity;
  resource_path: string [@key "resourcePath"];
  (* authorizer: Yojson.Safe.json StringMap.t; *)
  authorizer: string StringMap.t option [@default None];
  http_method: string [@key "httpMethod"];
  protocol: string option [@default None];
  path: string option [@default None];
  api_id: string [@key "apiId"] (* The API Gateway REST API ID *)
}
[@@deriving yojson { strict = false }]

type api_gateway_proxy_request = {
  resource: string;
  path: string;
  http_method: string [@key "httpMethod"];
  headers: string StringMap.t;
  query_string_parameters: string StringMap.t [@key "queryStringParameters"] [@default StringMap.empty];
  path_parameters: string StringMap.t [@key "pathParameters"] [@default StringMap.empty];
  stage_variables: string StringMap.t [@key "stageVariables"] [@default StringMap.empty];
  request_context: api_gateway_proxy_request_context [@key "requestContext"];
  body: string option;
  is_base64_encoded: bool [@key "isBase64Encoded"];
}
[@@deriving yojson { strict = false }]

type api_gateway_proxy_response = {
  status_code: int [@key "statusCode"];
  headers: string StringMap.t;
  body: string;
  is_base64_encoded: bool [@key "isBase64Encoded"];
}
[@@deriving yojson]

[@@@ocaml.warning "+39"]

module API_gateway_request = struct
  [@@@ocaml.warning "-39"]
  type t = api_gateway_proxy_request
  [@@deriving yojson]
end

module API_gateway_response = struct
  [@@@ocaml.warning "-39"]
  type t = api_gateway_proxy_response
  [@@deriving yojson]
end

module Runtime = Runtime.Make (API_gateway_request) (API_gateway_response)

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
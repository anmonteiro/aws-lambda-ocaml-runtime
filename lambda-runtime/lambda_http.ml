open Util

[@@@ocaml.warning "-39"]

(* APIGatewayRequestIdentity contains identity information for the request caller. *)
type api_gateway_request_identity = {
  cognito_identity_pool_id: string [@key "cognitoIdentityPoolId"];
  account_id: string [@key "accountId"];
  cognito_identity_id: string [@key "cognitoIdentityId"];
  caller: string;
  api_key: string [@key "apiKey"];
  source_ip: string [@key "sourceIp"];
  cognito_authentication_type: string [@key "cognitoAuthenticationType"];
  cognito_authentication_provider: string [@key "cognitoAuthenticationProvider"];
  user_arn: string [@key "userArn"];
  user_agent: string [@key "userAgent"];
  user: string;
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
  authorizer: string StringMap.t;
  http_method: string [@key "httpMethod"];
  api_id: string [@key "apiId"] (* The API Gateway REST API ID *)
}
[@@deriving yojson]

type api_gateway_proxy_request = {
  resource: string;
  path: string;
  http_method: string [@key "httpMethod"];
  headers: string StringMap.t;
  query_string_parameters: string StringMap.t [@key "queryStringParameters"];
  path_parameters: string StringMap.t [@key "pathParameters"];
  stage_variables: string StringMap.t [@key "stageVariables"];
  request_context: api_gateway_proxy_request_context [@key "requestContext"];
  body: string;
  is_base64_encoded: string option [@key "isBase64Encoded"];
}
[@@deriving yojson]

type api_gateway_proxy_response = {
  status_code: int [@key "statusCode"];
  headers: string StringMap.t;
  body: string;
  is_base64_encoded: bool [@key "isBase64Encoded"];
}
[@@deriving yojson]
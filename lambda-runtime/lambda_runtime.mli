open Lambda_runtime_private

module Client : sig
  include module type of Client
end

module Context : sig
  type t = {
    (* the amount of memory allocated to the lambda function in mb.
    this value is extracted from the `aws_lambda_function_memory_size`
    environment variable set by the lambda service. *)
    memory_limit_in_mb: int;

    (* the name of the lambda function as registered with the lambda
      service. the value is extracted from the `aws_lambda_function_name`
      environment variable set by the lambda service. *)
    function_name: string;

    (* the version of the function being invoked. this value is extracted
    from the `aws_lambda_function_version` environment variable set
    by the lambda service. *)
    function_version: string;

    (* the fully qualified arn (amazon resource name) for the function
    invocation event. this value is returned by the lambda runtime apis
    as a header. *)
    invoked_function_arn: string;

    (* the aws request id for the current invocation event. this value
    is returned by the lambda runtime apis as a header. *)
    aws_request_id: string;

    (* the x-ray trace id for the current invocation. this value is returned
    by the lambda runtime apis as a header. developers can use this value
    with the aws sdk to create new, custom sub-segments to the current
    invocation. *)
    xray_trace_id: string;

    (* the name of the cloudwatch log stream for the current execution
    environment. this value is extracted from the `aws_lambda_log_stream_name`
    environment variable set by the lambda service. *)
    log_stream_name: string;

    (* the name of the cloudwatch log group for the current execution
    environment. this value is extracted from the `aws_lambda_log_group_name`
    environment variable set by the lambda service. *)
    log_group_name: string;

    (* the client context sent by the aws mobile sdk with the invocation
    request. this value is returned by the lambda runtime apis as a
    header. this value is populated only if the invocation request
    originated from an aws mobile sdk or an sdk that attached the client
    context information to the request. *)
    client_context: Client.client_context option;

    (* the information of the cognito identity that sent the invocation
    request to the lambda service. this value is returned by the lambda
    runtime apis in a header and it's only populated if the invocation
    request was performed with aws credentials federated through the cognito
    identity service. *)
    identity: Client.cognito_identity option;

    (* the deadline for the current handler execution in nanoseconds based
      on a unix `monotonic` clock. *)
    deadline: int64;
  }
end

module Json : sig
  include Runtime_intf.LambdaRuntime with type event = Yojson.Safe.json
                                      and type response = Yojson.Safe.json

end

module Http : sig
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

  include Runtime_intf.LambdaRuntime with type event = api_gateway_proxy_request
                                      and type response = api_gateway_proxy_response
end
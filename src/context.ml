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

let make
    ~invoked_function_arn
    ~aws_request_id
    ~xray_trace_id
    ~client_context
    ~identity
    ~deadline
    settings =
  {
    memory_limit_in_mb = settings.Config.memory_size;
    function_name = settings.function_name;
    function_version = settings.version;
    log_stream_name = settings.log_stream;
    log_group_name = settings.log_group;
    invoked_function_arn;
    aws_request_id;
    xray_trace_id;
    client_context;
    identity;
    deadline;
  }

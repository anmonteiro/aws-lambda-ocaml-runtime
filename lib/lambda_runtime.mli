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

module Context : sig
  type t =
    { (* the amount of memory allocated to the lambda function in mb. this
         value is extracted from the `aws_lambda_function_memory_size`
         environment variable set by the lambda service. *)
      memory_limit_in_mb : int
    ; (* the name of the lambda function as registered with the lambda service.
         the value is extracted from the `aws_lambda_function_name` environment
         variable set by the lambda service. *)
      function_name : string
    ; (* the version of the function being invoked. this value is extracted
         from the `aws_lambda_function_version` environment variable set by the
         lambda service. *)
      function_version : string
    ; (* the fully qualified arn (amazon resource name) for the function
         invocation event. this value is returned by the lambda runtime apis as
         a header. *)
      invoked_function_arn : string
    ; (* the aws request id for the current invocation event. this value is
         returned by the lambda runtime apis as a header. *)
      aws_request_id : string
    ; (* the x-ray trace id for the current invocation. this value is returned
         by the lambda runtime apis as a header. developers can use this value
         with the aws sdk to create new, custom sub-segments to the current
         invocation. *)
      xray_trace_id : string option
    ; (* the name of the cloudwatch log stream for the current execution
         environment. this value is extracted from the
         `aws_lambda_log_stream_name` environment variable set by the lambda
         service. *)
      log_stream_name : string
    ; (* the name of the cloudwatch log group for the current execution
         environment. this value is extracted from the
         `aws_lambda_log_group_name` environment variable set by the lambda
         service. *)
      log_group_name : string
    ; (* the client context sent by the aws mobile sdk with the invocation
         request. this value is returned by the lambda runtime apis as a
         header. this value is populated only if the invocation request
         originated from an aws mobile sdk or an sdk that attached the client
         context information to the request. *)
      client_context : Client.client_context option
    ; (* the information of the cognito identity that sent the invocation
         request to the lambda service. this value is returned by the lambda
         runtime apis in a header and it's only populated if the invocation
         request was performed with aws credentials federated through the
         cognito identity service. *)
      identity : Client.cognito_identity option
    ; (* the deadline for the current handler execution in nanoseconds based on
         a unix `monotonic` clock. *)
      deadline : int64
    }
  [@@deriving yojson]
end

module StringMap : module type of Util.StringMap

module Runtime_intf : module type of Runtime_intf

module Make
    (Event : Runtime_intf.LambdaEvent)
    (Response : Runtime_intf.LambdaResponse) :
  Runtime_intf.LambdaRuntime
  with type event = Event.t
   and type response = Response.t

module Json : sig
  include
    Runtime_intf.LambdaRuntime
    with type event = Yojson.Safe.json
     and type response = Yojson.Safe.json
end

module Http : sig
  open Util

  (* APIGatewayRequestIdentity contains identity information for the request
     caller. *)
  type api_gateway_request_identity =
    { cognito_identity_pool_id : string option
    ; account_id : string option
    ; cognito_identity_id : string option
    ; caller : string option
    ; access_key : string option
    ; api_key : string option
    ; source_ip : string
    ; cognito_authentication_type : string option
    ; cognito_authentication_provider : string option
    ; user_arn : string option
    ; user_agent : string option
    ; user : string option
    }

  (* APIGatewayProxyRequestContext contains the information to identify the AWS
     account and resources invoking the Lambda function. It also includes
     Cognito identity information for the caller. *)
  type api_gateway_proxy_request_context =
    { account_id : string
    ; resource_id : string
    ; stage : string
    ; request_id : string
    ; identity : api_gateway_request_identity
    ; resource_path : string
    ; authorizer : string StringMap.t option
    ; http_method : string
    ; protocol : string option
    ; path : string option
    ; api_id : string (* The API Gateway REST API ID *)
    }

  type api_gateway_proxy_request =
    { resource : string
    ; path : string
    ; http_method : string
    ; headers : string StringMap.t
    ; query_string_parameters : string StringMap.t
    ; path_parameters : string StringMap.t
    ; stage_variables : string StringMap.t
    ; request_context : api_gateway_proxy_request_context
    ; body : string option
    ; is_base64_encoded : bool
    }

  type api_gateway_proxy_response =
    { status_code : int
    ; headers : string StringMap.t
    ; body : string
    ; is_base64_encoded : bool
    }

  include
    Runtime_intf.LambdaRuntime
    with type event = api_gateway_proxy_request
     and type response = api_gateway_proxy_response
end

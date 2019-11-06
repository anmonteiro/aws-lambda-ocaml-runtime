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

open Runtime_intf

module Context : sig
  type t =
    { memory_limit_in_mb : int
          (** The amount of memory allocated to the lambda function in MB. This
              value is extracted from the `AWS_LAMBDA_FUNCTION_MEMORY_SIZE`
              environment variable set by the lambda service. *)
    ; function_name : string
          (** The name of the lambda function as registered with the lambda
              service. The value is extracted from the
              `AWS_LAMBDA_FUNCTION_NAME` environment variable set by the lambda
              service. *)
    ; function_version : string
          (** The version of the function being invoked. This value is extracted
              from the `AWS_LAMBDA_FUNCTION_VERSION` environment variable set by
              the lambda service. *)
    ; invoked_function_arn : string
          (** The fully qualified ARN (Amazon Resource Name) for the function
              invocation event. This value is returned by the lambda runtime
              APIs as a header. *)
    ; aws_request_id : string
          (** The AWS Request ID for the current invocation event. This value is
              returned by the lambda runtime APIs as a header. *)
    ; xray_trace_id : string option
          (** The x-ray trace id for the current invocation. this value is
              returned by the lambda runtime apis as a header. developers can
              use this value with the aws sdk to create new, custom sub-segments
              to the current invocation. *)
    ; log_stream_name : string
          (** The name of the cloudwatch log stream for the current execution
              environment. this value is extracted from the
              `aws_lambda_log_stream_name` environment variable set by the
              lambda service. *)
    ; log_group_name : string
          (** The name of the CloudWatch log group for the current execution
              environment. This value is extracted from the
              `AWS_LAMBDA_LOG_GROUP_NAME` environment variable set by the lambda
              service. *)
    ; client_context : Client.client_context option
          (** The client context sent by the AWS Mobile SDK with the invocation
              request. This value is returned by the lambda runtime APIs as a
              header. This value is populated only if the invocation request
              originated from an AWS Mobile SDK or an SDK that attached the
              client context information to the request. *)
    ; identity : Client.cognito_identity option
          (** The information of the Cognito Identity that sent the invocation
              request to the lambda service. This value is returned by the
              lambda runtime APIs in a header and it's only populated if the
              invocation request was performed with AWS credentials federated
              through the Cognito Identity service. *)
    ; deadline : int64
          (** The deadline for the current handler execution in nanoseconds. *)
    }
end

module StringMap : module type of Util.StringMap

module type LambdaEvent = LambdaEvent

module type LambdaResponse = LambdaResponse

module type LambdaRuntime = LambdaRuntime

module Make (Event : LambdaEvent) (Response : LambdaResponse) :
  LambdaRuntime with type event := Event.t and type response := Response.t

module Json : sig
  include
    LambdaRuntime
      with type event := Yojson.Safe.t
       and type response := Yojson.Safe.t
end

module Http : sig
  open Util

  (* APIGatewayRequestIdentity contains identity information for the request
   * caller. *)
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
   * account and resources invoking the Lambda function. It also includes
   * Cognito identity information for the caller. *)
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
    ; api_id : string  (** The API Gateway REST API ID *)
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
    LambdaRuntime
      with type event := api_gateway_proxy_request
       and type response := api_gateway_proxy_response
end

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

type t =
  { (* the amount of memory allocated to the lambda function in mb. this value
       is extracted from the `aws_lambda_function_memory_size` environment
       variable set by the lambda service. *)
    memory_limit_in_mb : int
  ; (* the name of the lambda function as registered with the lambda service.
       the value is extracted from the `aws_lambda_function_name` environment
       variable set by the lambda service. *)
    function_name : string
  ; (* the version of the function being invoked. this value is extracted from
       the `aws_lambda_function_version` environment variable set by the lambda
       service. *)
    function_version : string
  ; (* the fully qualified arn (amazon resource name) for the function
       invocation event. this value is returned by the lambda runtime apis as a
       header. *)
    invoked_function_arn : string
  ; (* the aws request id for the current invocation event. this value is
       returned by the lambda runtime apis as a header. *)
    aws_request_id : string
  ; (* the x-ray trace id for the current invocation. this value is returned by
       the lambda runtime apis as a header. developers can use this value with
       the aws sdk to create new, custom sub-segments to the current
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
       request. this value is returned by the lambda runtime apis as a header.
       this value is populated only if the invocation request originated from
       an aws mobile sdk or an sdk that attached the client context information
       to the request. *)
    client_context : Client.client_context option
  ; (* the information of the cognito identity that sent the invocation request
       to the lambda service. this value is returned by the lambda runtime apis
       in a header and it's only populated if the invocation request was
       performed with aws credentials federated through the cognito identity
       service. *)
    identity : Client.cognito_identity option
  ; (* the deadline for the current handler execution in milliseconds based on
       a unix `monotonic` clock. *)
    deadline : int64
  }
[@@deriving yojson]

let make
    ~invoked_function_arn
    ~aws_request_id
    ~xray_trace_id
    ~client_context
    ~identity
    ~deadline
    settings
  =
  { memory_limit_in_mb = settings.Config.memory_size
  ; function_name = settings.function_name
  ; function_version = settings.version
  ; log_stream_name = settings.log_stream
  ; log_group_name = settings.log_group
  ; invoked_function_arn
  ; aws_request_id
  ; xray_trace_id
  ; client_context
  ; identity
  ; deadline
  }

(*----------------------------------------------------------------------------
 *  Copyright (c) 2018 António Nuno Monteiro
 *  Copyright (c) 2023 Christopher Armstrong
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

open Util

type api_gateway_proxy_request_context_http =
  { method_ : string [@key "method"]
  ; path : string
  ; protocol : string
  ; source_ip : string [@key "sourceIp"]
  ; user_agent : string [@key "userAgent"]
  }
[@@deriving of_yojson { strict = false }]

type api_gateway_request_context_jwt =
  { claims : string StringMap.t [@default StringMap.empty]
  ; scopes : string StringMap.t [@default StringMap.empty]
  }
[@@deriving of_yojson { strict = false }]

type api_gateway_proxy_request_context_authorizer =
  { jwt : api_gateway_request_context_jwt }
[@@deriving of_yojson { strict = false }]

(* APIGatewayProxyRequestContext contains the information to identify the AWS
 * account and resources invoking the Lambda function. It also includes Cognito
 * identity information for the caller. *)
type api_gateway_proxy_request_context =
  { account_id : string [@key "accountId"]
  ; api_id : string [@key "apiId"] (* The API Gateway REST API ID *)
  ; domain_name : string [@key "domainName"]
  ; domain_prefix : string [@key "domainPrefix"]
  ; http : api_gateway_proxy_request_context_http
  ; resource_id : string option [@key "resourceId"] [@default None]
  ; stage : string
  ; request_id : string [@key "requestId"]
  ; route_key : string [@key "routeKey"]
  ; time : string
  ; time_epoch : int64 [@key "timeEpoch"]
  ; authorizer : api_gateway_proxy_request_context_authorizer option
        [@default None]
  }
[@@deriving of_yojson { strict = false }]

type api_gateway_proxy_request =
  { version : string
  ; route_key : string [@key "routeKey"]
  ; raw_query_string : string [@key "rawQueryString"]
  ; cookies : string list option [@default None]
  ; headers : string StringMap.t
  ; query_string_parameters : string StringMap.t
        [@key "queryStringParameters"] [@default StringMap.empty]
  ; request_context : api_gateway_proxy_request_context [@key "requestContext"]
  ; body : string option [@default None]
  ; path_parameters : string StringMap.t
        [@key "pathParameters"] [@default StringMap.empty]
  ; is_base64_encoded : bool [@key "isBase64Encoded"]
  ; stage_variables : string StringMap.t
        [@key "stageVariables"] [@default StringMap.empty]
  }
[@@deriving of_yojson { strict = false }]

type api_gateway_proxy_response =
  { status_code : int [@key "statusCode"]
  ; headers : string StringMap.t
  ; body : string
  ; is_base64_encoded : bool [@key "isBase64Encoded"]
  }
[@@deriving to_yojson]

module API_gateway_request = struct
  type t = api_gateway_proxy_request [@@deriving of_yojson { strict = false }]
end

module API_gateway_response = struct
  type t = api_gateway_proxy_response [@@deriving to_yojson]
end

include Runtime.Make (API_gateway_request) (API_gateway_response)

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

open Util

(* APIGatewayRequestIdentity contains identity information for the request
 * caller. *)
type api_gateway_request_identity =
  { cognito_identity_pool_id : string option [@key "cognitoIdentityPoolId"]
  ; account_id : string option [@key "accountId"]
  ; cognito_identity_id : string option [@key "cognitoIdentityId"]
  ; caller : string option
  ; access_key : string option [@key "accessKey"]
  ; api_key : string option [@key "apiKey"] [@default None]
  ; source_ip : string [@key "sourceIp"]
  ; cognito_authentication_type : string option
        [@key "cognitoAuthenticationType"]
  ; cognito_authentication_provider : string option
        [@key "cognitoAuthenticationProvider"]
  ; user_arn : string option [@key "userArn"]
  ; user_agent : string option [@key "userAgent"]
  ; user : string option
  }
[@@deriving of_yojson]

(* APIGatewayProxyRequestContext contains the information to identify the AWS
 * account and resources invoking the Lambda function. It also includes Cognito
 * identity information for the caller. *)
type api_gateway_proxy_request_context =
  { account_id : string [@key "accountId"]
  ; resource_id : string [@key "resourceId"]
  ; stage : string
  ; request_id : string [@key "requestId"]
  ; identity : api_gateway_request_identity
  ; resource_path : string [@key "resourcePath"]
  ; (* authorizer: Yojson.Safe.json StringMap.t; *)
    authorizer : string StringMap.t option [@default None]
  ; http_method : string [@key "httpMethod"]
  ; protocol : string option [@default None]
  ; path : string option [@default None]
  ; api_id : string [@key "apiId"] (* The API Gateway REST API ID *)
  }
[@@deriving of_yojson { strict = false }]

type api_gateway_proxy_request =
  { resource : string
  ; path : string
  ; http_method : string [@key "httpMethod"]
  ; headers : string StringMap.t
  ; query_string_parameters : string StringMap.t
        [@key "queryStringParameters"] [@default StringMap.empty]
  ; path_parameters : string StringMap.t
        [@key "pathParameters"] [@default StringMap.empty]
  ; stage_variables : string StringMap.t
        [@key "stageVariables"] [@default StringMap.empty]
  ; request_context : api_gateway_proxy_request_context [@key "requestContext"]
  ; body : string option
  ; is_base64_encoded : bool [@key "isBase64Encoded"]
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
  type t = api_gateway_proxy_request [@@deriving of_yojson]
end

module API_gateway_response = struct
  type t = api_gateway_proxy_response [@@deriving to_yojson]

  let to_yojson t = Lwt.return (to_yojson t)
end

include Runtime.Make (API_gateway_request) (API_gateway_response)

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
  { memory_limit_in_mb : int
  ; function_name : string
  ; function_version : string
  ; invoked_function_arn : string
  ; aws_request_id : string
  ; xray_trace_id : string option
  ; log_stream_name : string
  ; log_group_name : string
  ; client_context : Client.client_context option
  ; identity : Client.cognito_identity option
  ; deadline : int64
  }

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

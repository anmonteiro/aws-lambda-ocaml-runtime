type now_proxy_request = Types.now_proxy_request =
  { path : string
  ; http_method : string
  ; host : string
  ; headers : string Lambda_runtime.StringMap.t
  ; body : string option
  }

type now_proxy_response = Types.now_proxy_response =
  { status_code : int
  ; headers : string Lambda_runtime.StringMap.t
  ; body : string
  ; encoding : string option
  }

include Lambda_runtime.Make (Types.Now_request) (Types.Now_response)

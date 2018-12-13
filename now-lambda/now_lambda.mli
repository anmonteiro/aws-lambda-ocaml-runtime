open Lambda_runtime

type now_proxy_request = {
  path: string;
  http_method: string [@key "method"];
  host: string;
  headers: string StringMap.t;
  body: string option
}

type now_proxy_response = {
  status_code: int [@key "statusCode"];
  headers: string Lambda_runtime.StringMap.t;
  body: string;
  encoding: string option;
}

include Lambda_runtime__Runtime_intf.LambdaRuntime with type event = now_proxy_request
                                                    and type response = now_proxy_response
open Lambda_runtime

let handler _event _ctx =
  Ok Http.{ status_code = 200
          ; headers = StringMap.empty
          ; body = "Hello world"
          ; is_base64_encoded = false }

let () =
  Lambda_runtime_dev.Http.lambda handler

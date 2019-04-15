module StringMap = Lambda_runtime.StringMap

let decode_body ~encoding body =
  match body, encoding with
  | None, _ ->
    None
  | Some body, Some "base64" ->
    (match Base64.decode body with Ok body -> Some body | Error _ -> None)
  | Some body, _ ->
    (* base64 is the only supported encoding *)
    Some body

let string_map_to_headers ?(init = Httpaf.Headers.empty) map =
  StringMap.fold
    (fun name value hs -> Httpaf.Headers.add hs name value)
    map
    init

let headers_to_string_map hs =
  Httpaf.Headers.fold ~f:StringMap.add ~init:StringMap.empty hs

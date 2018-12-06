module StringMap = struct
  include Map.Make(String)
  let find_opt k t =
    try
     Some (find k t)
    with Not_found -> None

  let to_yojson a_to_yojson t =
    let items = List.map (fun (key, v) -> key, a_to_yojson v) (bindings t)
    in
    `Assoc items

  let of_yojson a_of_yojson = function
  | `Assoc items ->
    let rec f map = function
    | [] -> Ok map
    | (name, json)::xs ->
      begin match a_of_yojson json with
      | Ok value -> f (add name value map) xs
      | Error _ as err -> err
      end
    in
    f empty items
  | _ -> Error "expected an object"
end
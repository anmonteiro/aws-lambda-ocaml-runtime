module StringMap = struct
  include Map.Make (String)

  let find_opt k t =
    match find k t with v -> Some v | exception Not_found -> None

  let to_yojson a_to_yojson t =
    let items = List.map (fun (key, v) -> key, a_to_yojson v) (bindings t) in
    `Assoc items

  let of_yojson a_of_yojson = function
    | `Assoc items ->
      let rec f map = function
        | [] ->
          Ok map
        | (name, json) :: xs ->
          (match a_of_yojson json with
          | Ok value ->
            f (add name value map) xs
          | Error _ as err ->
            err)
      in
      f empty items
    | `Null ->
      Ok empty
    | _ ->
      Error "expected an object"
end

let id : 'a. 'a -> 'a = fun x -> x

module Option = struct
  module Let_syntax = struct
    let map t ~f =
      match t with
      | None -> None
      | Some a -> Some (f a)

    let bind t ~f =
      match t with
      | None -> None
      | Some x -> f x

    (* let both x y ~f =
    match x, y with
    | Some a, Some b -> Some (f (a, b))
    | _ -> None *)
  end
end

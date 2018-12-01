module StringMap = struct
  include Map.Make(String)
  let find_opt k t =
    try
     Some (find k t)
    with Not_found -> None
end


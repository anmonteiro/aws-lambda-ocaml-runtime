module Id = struct
  type t = Yojson.Safe.json [@@deriving yojson]
end

include Runtime.Make (Id) (Id)

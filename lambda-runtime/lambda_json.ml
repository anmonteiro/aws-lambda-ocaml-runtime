module Id = struct
  [@@@ocaml.warning "-39"]

  type t = Yojson.Safe.json [@@deriving yojson]
end

include Runtime.Make (Id) (Id)

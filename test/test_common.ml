let yojson = (module struct
  type t = Yojson.Safe.json

  let pp formatter t =
    Format.pp_print_text formatter (Yojson.Safe.pretty_to_string t)

  let equal = (=)
end : Alcotest.TESTABLE with type t = Yojson.Safe.json)
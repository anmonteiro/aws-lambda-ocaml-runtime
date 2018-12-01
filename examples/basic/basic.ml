let my_handler evt _context =
  Ok evt

let () = Lambda_runtime.start my_handler
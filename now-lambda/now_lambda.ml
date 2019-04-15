include Lambda_runtime.Make (Types.Now_request) (Types.Now_response)

type handler_response = Types.Now_response.t

let respond_with_string response str = response, str

let respond_with_bigstring response ?(off = 0) ?len bstr =
  let len =
    match len with Some len -> len | None -> Bigstringaf.length bstr
  in
  response, Bigstringaf.substring ~off ~len bstr

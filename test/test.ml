let () =
  Alcotest.run
    "lambda-runtime"
    [ "config", Config_test.suite
    ; "runtime", Runtime_test.suite
    ; "API Gateway", Api_gateway_test.suite
    ; "Vercel Lambda", Vercel_test.suite
    ]

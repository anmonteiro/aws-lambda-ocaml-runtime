let () =
  Alcotest.run
    "lambda-runtime"
    [ "config", Config_test.suite
    ; "runtime", Runtime_test.suite
    ; "API Gateway", Api_gateway_test.suite
    ; "Now Lambda", Now_lambda_test.suite
    ]

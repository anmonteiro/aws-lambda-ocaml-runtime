let () =
  Alcotest.run "lambda-runtime" [
    "config", Config_test.suite;
  ]
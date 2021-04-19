# OCaml Runtime for AWS Lambda

This package provides a [custom
runtime](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html) for
AWS Lambda.

## Installation

This repository provides two libraries:

- `lambda-runtime` provides a runtime and API for
  [AWS Lambda](https://aws.amazon.com/lambda/) and
  [API Gateway](https://aws.amazon.com/api-gateway/).
- the `vercel` library depends on `lambda-runtime` and provides an interface to
  the [Vercel](https://vercel.com/) service that resembles a request / response
  exchange.


The libraries in this repo are released to the OPAM package registry.

You can depend on them via:

1. [__esy__](esy): `esy add @opam/lambda-runtime` and / or `esy add @opam/vercel`
2. [__OPAM__](opam): `opam install lambda-runtime vercel`.

[esy]: https://esy.sh
[opam]: https://opam.ocaml.org

## Example function

See the [`examples`](./examples) folder.

## Deploying

**Note**: Based on the instructions in this [blog
post](https://aws.amazon.com/blogs/opensource/rust-runtime-for-aws-lambda/) and
the Rust custom runtime
[repository](https://github.com/awslabs/aws-lambda-rust-runtime)

For a custom runtime, AWS Lambda looks for an executable called `bootstrap` in
the deployment package zip. Rename the generated `basic` executable to
`bootstrap` and add it to a zip archive.

The Dockerfile (in conjunction with the [`build.sh`](./build.sh) script) in this
repo does just that. It builds a static binary called `bootstrap` and drops it
in the target directory.

```shell
$ ./build.sh && zip -j ocaml.zip bootstrap
```

Now that we have a deployment package (`ocaml.zip`), we can use the [AWS
CLI](https://aws.amazon.com/cli/) to create a new Lambda function. Make sure to
replace the execution role with an existing role in your account!

```shell
$ aws lambda create-function --function-name OCamlTest \
  --handler doesnt.matter \
  --zip-file file://./ocaml.zip \
  --runtime provided \
  --role arn:aws:iam::XXXXXXXXXXXXX:role/your_lambda_execution_role \
  --tracing-config Mode=Active
```

You can now test the function using the AWS CLI or the AWS Lambda console

```shell
$ aws lambda invoke --function-name OCamlTest \
  --payload '{"firstName": "world"}' \
  output.json
$ cat output.json  # Prints: {"message":"Hello, world!"}
```

## Copyright & License

Copyright © 2018 António Nuno Monteiro

Distributed under the 3-clause BSD License (see [LICENSE](./LICENSE)).

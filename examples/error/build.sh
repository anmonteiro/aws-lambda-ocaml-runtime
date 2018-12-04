#!/usr/bin/env sh

set -eo pipefail

root_path=$PWD

# Start in examples/basic/ even if run from root directory
cd "$(dirname "$0")"

rm -rf bootstrap
docker build ../.. --tag lambda-error -f ./Dockerfile
docker rm example-error || true
docker create --name example-error lambda-error
docker cp example-error:/app/bootstrap bootstrap

cd $root_path
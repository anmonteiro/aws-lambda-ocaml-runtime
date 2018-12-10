#!/usr/bin/env sh

set -eo pipefail

root_path=$PWD

# Start in examples/api-gateway/ even if run from root directory
cd "$(dirname "$0")"

rm -rf bootstrap
docker build ../.. --tag lambda -f ./Dockerfile
docker rm example || true
docker create --name example lambda
docker cp example:/app/bootstrap bootstrap

cd $root_path
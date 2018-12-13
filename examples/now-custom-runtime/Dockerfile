# start from node image so we can install esy from npm

FROM node:10.13-alpine as build

ENV TERM=dumb LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib

RUN mkdir /esy
WORKDIR /esy

ENV NPM_CONFIG_PREFIX=/esy
RUN npm install -g --unsafe-perm esy@0.4.3

# now that we have esy installed we need a proper runtime

FROM alpine:3.8 as esy

ENV TERM=dumb LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib

WORKDIR /

COPY --from=build /esy /esy

RUN apk add --no-cache ca-certificates wget bash curl perl-utils git patch gcc g++ musl-dev make m4

RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
RUN wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.28-r0/glibc-2.28-r0.apk
RUN apk add --no-cache glibc-2.28-r0.apk

ENV PATH=/esy/bin:$PATH

RUN mkdir /app
WORKDIR /app

COPY esy.json esy.json
COPY esy.lock esy.lock

RUN esy fetch
RUN esy build-package @esy-ocaml/substs
RUN esy build-package @opam/conf-m4
RUN esy build-package ocaml@4.7.1003
RUN esy build-package @opam/ocamlfind
RUN esy build-package @opam/base-bytes
RUN esy build-package @opam/ocamlbuild
RUN esy build-package @opam/base-threads
RUN esy build-package @opam/base-unix
RUN esy build-package @opam/dune
RUN esy build-package @opam/jbuilder
RUN esy build-package @opam/result
RUN esy build-package @opam/topkg
RUN esy build-package @opam/astring
RUN esy build-package @opam/cmdliner
RUN esy build-package @opam/uchar
RUN esy build-package @opam/fmt
RUN esy build-package @opam/uuidm
RUN esy build-package @opam/alcotest
RUN esy build-package @opam/base-bigarray
RUN esy build-package @opam/bigstringaf
RUN esy build-package @opam/faraday
RUN esy build-package @opam/cppo
RUN esy build-package @opam/lwt
RUN esy build-package @opam/faraday-lwt
RUN esy build-package @opam/faraday-lwt-unix
RUN esy build-package @opam/angstrom
RUN esy build-package @opam/httpaf
RUN esy build-package @opam/httpaf-lwt
RUN esy build-package @opam/logs
RUN esy build-package @opam/cppo_ocamlbuild
RUN esy build-package @opam/ocaml-migrate-parsetree
RUN esy build-package @opam/ppx_derivers
RUN esy build-package @opam/ppx_tools
RUN esy build-package @opam/ppx_deriving
RUN esy build-package @opam/ppxfind
RUN esy build-package @opam/conf-which
RUN esy build-package @opam/easy-format
RUN esy build-package @opam/biniou
RUN esy build-package @opam/yojson
RUN esy build-package @opam/ppx_deriving_yojson
RUN esy build-package @opam/sexplib0
RUN esy build-package @opam/base
RUN esy build-package @opam/ocaml-compiler-libs
RUN esy build-package @opam/stdio
RUN esy build-package @opam/ppxlib
RUN esy build-package @opam/ppx_sexp_conv
RUN esy build-package @opam/seq
RUN esy build-package @opam/re
RUN esy build-package @opam/stringext
RUN esy build-package @opam/uri
RUN esy build-package @opam/base64

COPY . .

RUN esy b dune build examples/now-custom-runtime/basic.exe --profile=static

RUN mv $(esy bash -c 'echo $cur__target_dir/default/examples/now-custom-runtime/basic.exe') bootstrap

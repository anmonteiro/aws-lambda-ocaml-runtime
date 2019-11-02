# start from node image so we can install esy from npm

FROM node:alpine as build

ENV TERM=dumb LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib

RUN mkdir /esy
WORKDIR /esy

ENV NPM_CONFIG_PREFIX=/esy
RUN npm install -g --unsafe-perm esy

# now that we have esy installed we need a proper runtime

FROM alpine as esy

ENV TERM=dumb LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib

WORKDIR /

COPY --from=build /esy /esy

RUN apk add --no-cache ca-certificates wget bash curl perl-utils git patch gcc g++ musl-dev make m4 coreutils

RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
RUN wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.30-r0/glibc-2.30-r0.apk
RUN apk add --no-cache glibc-2.30-r0.apk

ENV PATH=/esy/bin:$PATH

RUN mkdir /app
WORKDIR /app

RUN echo ' \
{\
  "name": "package-base", \
  "dependencies": { \
    "ocaml": "4.9.0", \
    "@opam/dune": "*" \
  } \
} \
' > esy.json

RUN esy

COPY esy.json esy.json
COPY esy.lock esy.lock

RUN esy fetch
RUN esy true

COPY . .

RUN esy b dune build examples/api-gateway/basic.exe --profile=static

RUN mv $(esy bash -c 'echo $cur__target_dir/default/examples/api-gateway/basic.exe') bootstrap

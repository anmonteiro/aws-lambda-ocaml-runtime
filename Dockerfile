FROM alpine:3.8 as base

ENV TERM=dumb \
    LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib

WORKDIR /app

RUN apk add --no-cache nodejs-current npm \
    libev yarn libev-dev python jq \
    ca-certificates wget \
		bash curl perl-utils \
		git patch gcc g++ musl-dev make m4 util-linux

RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
RUN wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.28-r0/glibc-2.28-r0.apk
RUN apk add --no-cache glibc-2.28-r0.apk

RUN npm install -g esy@next --unsafe-perm

COPY package.json package.json

RUN esy install
RUN esy

COPY . .

RUN esy b dune build @all --profile=static

RUN mv $(esy bash -c 'echo $cur__target_dir/default/examples/basic/basic.exe') bootstrap

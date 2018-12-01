define DOCKERFILE_ESY
# start from node image so we can install esy from npm

FROM node:10.13-alpine as build

ENV TERM=dumb \
		LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib

RUN mkdir /esy
WORKDIR /esy

ENV NPM_CONFIG_PREFIX=/esy
RUN npm install -g --unsafe-perm esy@0.4.3

# now that we have esy installed we need a proper runtime

FROM alpine:3.8 as esy

ENV TERM=dumb \
		LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib

WORKDIR /

COPY --from=build /esy /esy

RUN apk add --no-cache \
		ca-certificates wget \
		bash curl perl-utils \
		git patch gcc g++ musl-dev make m4

RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
RUN wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.28-r0/glibc-2.28-r0.apk
RUN apk add --no-cache glibc-2.28-r0.apk

ENV PATH=/esy/bin:$$PATH
endef
export DOCKERFILE_ESY

define DOCKERIGNORE
.git
node_modules
_esy
endef
export DOCKERIGNORE

define GEN_DOCKERFILE_APP
let fs = require('fs');
let childProcess = require('child_process');

let lock = JSON.parse(fs.readFileSync('./esy.lock/index.json').toString('utf8'));

function findAllPackageIds(lock) {
  let ids = [];

  function traveseDependencies(id) {
    let node = lock.node[id];
    let dependencies = node.dependencies || [];
    let devDependencies = node.devDependencies || [];

    let allDependencies = dependencies.concat(devDependencies);
    allDependencies.sort();

    for (let dep of allDependencies) {
      traverse(dep, lock.node[dep])
    }
  }

  function traverse(id) {
    let [name, version, _hash] = id.split('@');
    let pkgid = `$${name}@$${version}`;
    if (ids.indexOf(pkgid) !== -1) {
      return;
    }
    traveseDependencies(id);
    ids.push(pkgid);
  }

  traveseDependencies(lock.root, lock.node[lock.root]);

  return ids;
}

let pkgs = findAllPackageIds(lock);

const build = pkgs.map(pkg => `RUN esy build-package $${pkg}`);

const esyImageId = process.argv[1];

const lines = [
  `FROM $${esyImageId}`,
  'RUN mkdir /app',
  'WORKDIR /app',
  'COPY package.json package.json',
  'COPY esy.lock esy.lock',
  'RUN esy fetch',
  ...build,
  'COPY . .',
]

console.log(lines.join('\n'));
endef
export GEN_DOCKERFILE_APP

define USAGE
Welcome to esy-docker!

This is a set of make rules to produce docker images for esy projects.

You can execute the following targets:

	esy-docker-build 		   Builds an application
	esy-docker-shell       Builds an application and executes bash in a container

endef
export USAGE

.DEFAULT: print-usage

print-usage:
	@echo "$$DOCKERFILE_ESY" > $(@)

.docker:
	@mkdir -p $(@)

.PHONY: .docker/Dockerfile.esy
.docker/Dockerfile.esy: .docker
	@echo "$$DOCKERFILE_ESY" > $(@)

.PHONY: Dockerfile.app
.docker/Dockerfile.app: .docker .docker/image.esy
	@node -e "$$GEN_DOCKERFILE_APP" $$(cat .docker/image.esy) > $(@)

.dockerignore:
	@echo "$$DOCKERIGNORE" > $(@)

.docker/image.esy: .docker .dockerignore .docker/Dockerfile.esy
	@docker build . -f .docker/Dockerfile.esy --iidfile $(@)

.docker/image.app: .docker .dockerignore .docker/Dockerfile.app
	@docker build . -f .docker/Dockerfile.app --iidfile $(@)

esy-docker-shell-esy: .docker/image.esy
	@docker run -it $$(cat .docker/image.esy) /bin/bash

esy-docker-build: .docker/image.app
	@docker run -it $$(cat .docker/image.app) esy build

esy-docker-shell: .docker/image.app
	@docker run -it $$(cat .docker/image.app) /bin/bash

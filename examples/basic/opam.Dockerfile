FROM ocaml/opam2:alpine-3.7-ocaml-4.07 as base

RUN sudo apk add --no-cache libev yarn m4 libev-dev python util-linux

USER opam

RUN opam switch create 4.07.1+flambda+no-flat-float-array

WORKDIR /app

COPY --chown=opam:nogroup *.opam /app/

RUN opam update

RUN opam pin add httpaf --dev-repo --yes && \
    opam pin add httpaf-lwt https://github.com/inhabitedtype/httpaf --kind=git --yes

RUN opam install . --deps-only --yes

RUN opam install fmt

RUN sudo chown -R opam:nogroup .

COPY --chown=opam:nogroup . /app

RUN opam config exec -- dune build examples/basic/basic.exe --profile=static

RUN mv _build/default/examples/basic/basic.exe bootstrap

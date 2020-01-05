{ pkgs ? import <nixpkgs> {}, ocamlVersion }:

let
  inherit (pkgs) lib stdenv fetchTarball;
  overlays = builtins.fetchTarball https://github.com/anmonteiro/nix-overlays/archive/master.tar.gz;
  ocamlPackages = pkgs.ocaml-ng."ocamlPackages_${ocamlVersion}".overrideScope'
    (pkgs.callPackage "${overlays}/ocaml" { });

  lambda-pkgs = import ./.. { inherit pkgs ocamlVersion; };
  lambda-drvs = lib.filterAttrs (_: value: lib.isDerivation value) lambda-pkgs;
in
  stdenv.mkDerivation {
    name = "lambda-runtime-tests";
    src = ./../..;
    dontBuild = true;
    installPhase = ''
      touch $out
    '';
    buildInputs = (lib.attrValues lambda-drvs) ++ (with ocamlPackages; [ ocaml dune findlib pkgs.ocamlformat reason ]);
    doCheck = true;
    checkPhase = ''
      # Check code is formatted with OCamlformat
      dune build @fmt
    '';
  }

{ ocamlVersion }:

let
  pkgs = import ../sources.nix { inherit ocamlVersion; };
  inherit (pkgs) lib stdenv fetchTarball ocamlPackages;

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
      dune build @examples/all
    '';
  }

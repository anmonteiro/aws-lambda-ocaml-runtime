{ pkgs ? import ./sources.nix { inherit ocamlVersion; }
, ocamlVersion ? "4_09" }:

let
  inherit (pkgs) lib stdenv ocamlPackages;
in

  with ocamlPackages;
  let
    build-lambda-runtime = args: buildDunePackage ({
      useDune2=true;
      version = "0.1.0-dev";
      src = lib.gitignoreSource ./..;
    } // args);

  in rec {
    lambda-runtime = build-lambda-runtime {
      pname = "lambda-runtime";
      buildInputs = [ alcotest ];
      doCheck = false;
      propagatedBuildInputs = [ yojson ppx_deriving_yojson piaf uri logs lwt4 ];
    };

    now = build-lambda-runtime {
      pname = "now";
      buildInputs = [ alcotest ];
      # tests lambda-runtime too
      doCheck = true;
      propagatedBuildInputs = [
        lambda-runtime
        httpaf
        yojson
        ppx_deriving_yojson
        lwt4
        base64
      ];
    };
}

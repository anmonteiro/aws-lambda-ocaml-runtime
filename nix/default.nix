{ ocamlVersion ? "4_11"
, pkgs ? import ./sources.nix { inherit ocamlVersion; }
}:

let
  inherit (pkgs) lib stdenv ocamlPackages;
in

  with ocamlPackages;
  let
    genSrc = { dirs, files }: lib.filterGitSource {
      src = ./..;
      inherit dirs;
      files = files ++ [ "dune-project" ];
    };
    build-lambda-runtime = args: buildDunePackage ({
      useDune2=true;
      version = "0.1.0-dev";
    } // args);

  in rec {
    lambda-runtime = build-lambda-runtime {
      pname = "lambda-runtime";
      src = genSrc {
        dirs = [ "lib" ];
        files = [ "lambda-runtime.opam" ];
      };
      buildInputs = [ alcotest ];
      doCheck = false;
      propagatedBuildInputs = [ yojson ppx_deriving_yojson piaf uri logs lwt ];
    };

    vercel = build-lambda-runtime {
      pname = "vercel";
      src = genSrc {
        dirs = [ "vercel" "test" ];
        files = [ "vercel.opam" ];
      };
      buildInputs = [ alcotest ];
      # tests lambda-runtime too
      doCheck = true;
      propagatedBuildInputs = [
        lambda-runtime
        piaf
        yojson
        ppx_deriving_yojson
        lwt
        base64
      ];
    };
}

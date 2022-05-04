{ ocamlVersion }:

let
  lock = builtins.fromJSON (builtins.readFile ./../../flake.lock);
  src = fetchGit {
    url = with lock.nodes.nixpkgs.locked;"https://github.com/${owner}/${repo}";
    inherit (lock.nodes.nixpkgs.locked) rev;
  };
  pkgs = import "${src}/boot.nix" {
    extraOverlays = [
      (self: super: {
        ocamlPackages = super.ocaml-ng."ocamlPackages_${ocamlVersion}";

        pkgsCross.musl64 = super.pkgsCross.musl64 // {
          ocamlPackages = super.pkgsCross.musl64.ocaml-ng."ocamlPackages_${ocamlVersion}";
        };
      })
    ];
  };

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

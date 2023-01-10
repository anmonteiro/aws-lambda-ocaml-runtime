{ ocamlVersion }:

let
  lock = builtins.fromJSON (builtins.readFile ./../../flake.lock);
  src = fetchGit {
    url = with lock.nodes.nixpkgs.locked;"https://github.com/${owner}/${repo}";
    inherit (lock.nodes.nixpkgs.locked) rev;
  };

  nix-filter-src = fetchGit {
    url = with lock.nodes.nix-filter.locked; "https://github.com/${owner}/${repo}";
    inherit (lock.nodes.nix-filter.locked) rev;
    # inherit (lock.nodes.nixpkgs.original) ref;
    allRefs = true;
  };
  nix-filter = import "${nix-filter-src}";

  pkgs = import src {
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

  lambda-pkgs = import ./.. { inherit pkgs nix-filter; };
  lambda-drvs = lib.filterAttrs (_: value: lib.isDerivation value) lambda-pkgs;
in
stdenv.mkDerivation {
  name = "lambda-runtime-tests";
  src = ./../..;
  dontBuild = true;
  installPhase = ''
    touch $out
  '';
  buildInputs = (lib.attrValues lambda-drvs) ++ (with ocamlPackages; [ ocaml dune findlib ocamlformat reason ]);
  doCheck = true;
  checkPhase = ''
    # Check code is formatted with OCamlformat
    dune build @fmt
    dune build @examples/all
  '';
}

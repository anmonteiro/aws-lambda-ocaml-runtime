{ packages, pkgs, release-mode ? false }:

let
  inherit (pkgs) stdenv lib;
  lambdaDrvs = lib.filterAttrs (_: value: lib.isDerivation value) packages;

in
(pkgs.mkShell {
  inputsFrom = lib.attrValues lambdaDrvs;
  buildInputs = (if release-mode then
    (with pkgs; [
      cacert
      curl
      ocamlPackages.dune-release
      git
      opam
    ]) else [ ]) ++ (with pkgs.ocamlPackages; [ merlin pkgs.ocamlformat ]);
}).overrideAttrs (o: {
  propagatedBuildInputs = lib.filter
    (drv:
      # we wanna filter our own packages so we don't build them when entering
      # the shell. They always have `pname`
      !(lib.hasAttr "pname" drv) ||
      drv.pname == null ||
      !(lib.any (name: name == drv.pname) (lib.attrNames lambdaDrvs)))
    o.propagatedBuildInputs;
})

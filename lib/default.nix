{
  version,
  yants,
}: let
  types = import ./types.nix {inherit yants;};
in {
  mkNeovimPkg = import ./mkNeovimPkg.nix {inherit version types;};
  mkPluginsFromInputs = import ./mkPluginsFromInputs.nix;
}

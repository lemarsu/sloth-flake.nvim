{
  description = "My neovim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    nil.url = "github:oxalica/nil";
    yants.url = "github:divnix/yants";
    alejandra = {
      url = "github:kamadorueda/alejandra/3.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    alejandra,
    nixpkgs,
    utils,
    yants,
    ...
  } @ inputs: let
    inherit (builtins) readFile replaceStrings;
    fu = utils.lib;
    versionFile = replaceStrings ["\n"] [""] (readFile ./VERSION);
    version =
      if self.sourceInfo ? dirtyShortRev
      then "${versionFile}-${self.sourceInfo.dirtyShortRev}"
      else versionFile;

    forSystem = system: let
      pkgs = nixpkgs.legacyPackages.${system};
      formatter = alejandra.defaultPackage.${system};
      inherit (inputs.nil.packages.${system}) nil;
    in {
      inherit formatter;
      devShells.default = import ./shell.nix {
        inherit pkgs nil formatter;
      };
    };
  in
    (fu.eachDefaultSystem forSystem)
    // {lib = import ./lib {inherit version yants;};};
}

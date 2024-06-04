{
  description = "My neovim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:gytis-ivaskevicius/flake-utils-plus/v1.4.0";
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
    versionFile = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./VERSION);

    version = if self.sourceInfo ? dirtyShortRev
    then "${versionFile}-${self.sourceInfo.dirtyShortRev}"
    else versionFile;
  in
    utils.lib.mkFlake {
      inherit self inputs;
      outputsBuilder = channel: let
        system = channel.nixpkgs.system;
      in {
        formatter = alejandra.defaultPackage.${channel.nixpkgs.system};
        devShells.default = import ./shell.nix {
          pkgs = channel.nixpkgs;
          inherit (inputs.nil.packages.${system}) nil;
        };
      };

      lib = import ./lib {inherit version yants;};
    };
}

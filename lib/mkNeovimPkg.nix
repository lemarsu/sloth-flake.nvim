{
  version,
  types,
}: {
  pkgs,
  package ? pkgs.neovim-unwrapped,
  dependencies ? [],
  dependenciesExtraArgs ? {},
  runtime ? {},
  viAlias ? false,
  vimAlias ? false,
  vimdiffAlias ? false,
  nvimdiffAlias ? false,
  ...
} @ config: let
  inherit (builtins) map;
  inherit (pkgs) callPackage bash lib;
  inherit (lib.strings) optionalString;
  inherit (lib.trivial) flip;
  # inherit (lib.lists) concatMap filter foldl' map optional reverseList;
  # inherit (lib.attrsets) attrNames optionalAttrs;
  # inherit (lib.strings) concatStringsSep fileContents hasSuffix removePrefix removeSuffix replaceStrings;
  # inherit (lib.debug) traceIf traceSeq traceVal traceValSeq traceValFn;

  deps = callPackage ./deps.nix {inherit dependenciesExtraArgs types;};

  normalizedPlugins = deps.normalizePlugins dependencies;
  sloth-flake = deps.mkSlothFlakePlugin version normalizedPlugins;
  runtimePlugin = deps.mkRuntimePlugin runtime;
  plugins =
    normalizedPlugins
    ++ (deps.normalizePlugins [runtimePlugin sloth-flake]);

  extractPlugin = p: {inherit (p) optional plugin;};
  extractPlugins = map extractPlugin;

  customRC = let
    rc = ({init ? ../lua/default_init.lua, ...}: init) runtime;
  in
    deps.textOrContent rc;

  neovimConfig =
    pkgs.neovimUtils.makeNeovimConfig {
      inherit customRC;
      plugins = extractPlugins plugins;
    }
    // {luaRcContent = customRC;};
  params =
    removeAttrs neovimConfig ["manifestRc" "neovimRcContent"]
    // {inherit viAlias vimAlias;};
  pkg = pkgs.wrapNeovimUnstable package params;
  mkDiffAlias = name:
    (flip optionalString) ''
      cat <<SH > $out/bin/${name}
      #!${bash}/bin/bash
      exec $out/bin/nvim -d "\''${@}"
      SH
      chmod 555 $out/bin/${name}
    '';
in
  builtins.seq (types.mkNeovimPkgOptions config) (pkg.overrideAttrs (final: super: {
    postBuild =
      super.postBuild
      + (mkDiffAlias "vimdiff" vimdiffAlias)
      + (mkDiffAlias "nvimdiff" nvimdiffAlias);
  }))

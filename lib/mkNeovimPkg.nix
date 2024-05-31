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
  ...
} @ config: let
  inherit (builtins) map;
  inherit (pkgs) callPackage;
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

  extractPlugin = p: {
    inherit (p) plugin;
    optional = p.lazy;
  };
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
in
  builtins.seq (types.mkNeovimPkgOptions config) pkg

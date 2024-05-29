{
  version,
  types,
}: {
  pkgs,
  package ? pkgs.neovim-unwrapped,
  dependencies ? [],
  dependenciesExtraArgs ? {},
  runtime ? {},
  ...
} @ config: let
  inherit (builtins) map;
  inherit (pkgs) callPackage;
  # inherit (lib.lists) concatMap filter foldl' map optional reverseList;
  # inherit (lib.attrsets) attrNames optionalAttrs;
  # inherit (lib.strings) concatStringsSep fileContents hasSuffix removePrefix removeSuffix replaceStrings;
  # inherit (lib.debug) traceIf traceSeq traceVal traceValSeq traceValFn;

  deps = callPackage ./deps.nix {inherit dependenciesExtraArgs types;};

  sloth-flake.plugin = deps.mkSlothFlakePlugin version plugins;
  runtimePlugin.plugin = deps.mkRuntimePlugin runtime;
  plugins = deps.normalizePlugins (dependencies ++ [runtimePlugin sloth-flake]);

  extractPlugin = p: {
    inherit (p) plugin;
    optional = p ? lazy && p.lazy || p ? cmd;
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
  pkg = pkgs.wrapNeovimUnstable package (removeAttrs neovimConfig ["manifestRc" "neovimRcContent"]);
in
  builtins.seq (types.mkNeovimPkgOptions config) pkg

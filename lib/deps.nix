{
  pkgs,
  lib,
  vimUtils,
  dependenciesExtraArgs,
  types,
  ...
}: let
  inherit (builtins) isPath;
  inherit (lib.attrsets) attrNames optionalAttrs;
  inherit (lib.lists) concatMap optional;
  inherit (lib.strings) concatStringsSep fileContents;
  lua = callPackage ./lua.nix {};

  callPackage = lib.callPackageWith (pkgs // dependenciesExtraArgs);

  defaultPlugin = {
    enabled = true;
    init = null;
    config = null;
  };

  remotePluginToNeovimPlugin = p:
    vimUtils.buildVimPlugin rec {
      inherit (p) src name;
      pname = name;
    };

  withPluginDefaults = dep: defaultPlugin // dep;
  normalizePlugin = d: let
    dep = types.dependency d;
    p =
      if ! dep ? plugin
      then {plugin = dep;}
      else let
        inherit (dep) plugin;
      in
        if attrNames plugin == ["name" "src"]
        then {plugin = remotePluginToNeovimPlugin plugin;}
        else dep;
  in
    withPluginDefaults p;

  normalizeOrImportPlugin = dep:
    if isPath dep
    then normalizePlugins (callPackage dep {})
    else [(normalizePlugin dep)];
  normalizePlugins = concatMap normalizeOrImportPlugin;

  mkRuntimePlugin = {
    src,
    version,
    ...
  }:
    vimUtils.buildVimPlugin ({
        inherit src;
      }
      // (optionalAttrs (isNull version) {
        name = "runtime";
      })
      // (optionalAttrs (! isNull version) {
        inherit version;
        pname = "runtime";
      }));

  mkSlothFlakePlugin = version: plugins: let
    getLua = type: p: let
      content = p.${type};
      textContent = textOrContent content;
      pluginName =
        if p.plugin ? name
        then p.plugin.name
        else baseNameOf p.plugin;
    in
      optional (! isNull content)
      (lua.wrapSelfInvokingFunction {
        section = "${type} for ${pluginName}";
        lua = textContent;
      });

    getAllLua = type:
      concatStringsSep "\n"
      (concatMap (getLua type) plugins);
  in
    vimUtils.buildVimPlugin {
      inherit version;
      pname = "sloth-flake";
      src = ../lua/sloth-flake;
      buildPhase = ''
        dir=lua/sloth-flake
        mkdir -p $dir
        mv init.lua $dir

        cat <<'LUA' > $dir/initialize.lua
        ${lua.wrapReturnFunction (getAllLua "init")}
        LUA

        cat <<'LUA' > $dir/config.lua
        ${lua.wrapReturnFunction (getAllLua "config")}
        LUA
      '';
    };

  textOrContent = content:
    if isPath content
    then fileContents content
    else content;
in {
  inherit normalizePlugins;
  inherit mkSlothFlakePlugin;
  inherit mkRuntimePlugin;
  inherit textOrContent;
}

{
  pkgs,
  lib,
  vimUtils,
  dependenciesExtraArgs,
  types,
  ...
}: let
  inherit (builtins) isPath foldl';
  inherit (lib.attrsets) attrNames optionalAttrs;
  inherit (lib.lists) concatMap;
  inherit (lib.strings) fileContents;
  lua = callPackage ./lua.nix {};

  callPackage = lib.callPackageWith (pkgs // dependenciesExtraArgs);

  defaultPlugin = {
    enabled = true;
    init = null;
    config = null;
    dependencies = [];
    lazy = false;
    cmd = [];
    ft = [];
  };

  remotePluginToNeovimPlugin = p:
    vimUtils.buildVimPlugin rec {
      inherit (p) src name;
      pname = name;
    };

  withPluginDefaults = dep: defaultPlugin // dep;
  normalizePlugin = d: let
    dep = types.dependency d;
    plugin =
      if ! dep ? plugin
      then {plugin = dep;}
      else let
        inherit (dep) plugin;
      in
        if attrNames plugin == ["name" "src"]
        then {plugin = remotePluginToNeovimPlugin plugin;}
        else dep;
    p = withPluginDefaults plugin;
  in
    p
    // rec {
      hasCommands = p.cmd != [];
      hasFileTypes = p.ft != [];
      lazy = p.lazy || hasCommands || hasFileTypes;
    };

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

  mkSlothFlakePlugin = version: plugins:
    vimUtils.buildVimPlugin {
      inherit version;
      pname = "sloth-flake";
      src = ../lua/sloth-flake;
      buildPhase = ''
        dir=lua/sloth-flake
        mkdir -p $dir
        mv init.lua $dir

        cat <<'LUA' > $dir/deps.lua
        ${pluginsLuaDef plugins}
        LUA

        cat <<'LUA' > $dir/version.lua
        ${versionLua version}
        LUA
      '';
    };

  versionLua = version: with lua; nix2lua (return (lambda (return version)));

  textOrContent = content:
    if isPath content
    then fileContents content
    else content;

  pluginLuaDef = memo: plugin: let
    # plugin = builtins.removeAttrs plugin ["dependencies" "plugin"];
    mkTypeFn = type: let
      content = textOrContent plugin.${type};
    in
      optionalAttrs (! isNull plugin.${type}) {
        ${type} = with lua; lambda (raw content);
      };
    pluginName = plugin:
      if plugin ? pname
      then plugin.pname
      else plugin.name;
    name = pluginName plugin.plugin;
  in
    memo
    // {
      ${name} =
        {
          name = pluginName plugin.plugin;
          dependencies = map pluginName plugin.dependencies;
        }
        // (mkTypeFn "init")
        // (mkTypeFn "config")
        // (optionalAttrs plugin.lazy {
          lazy = true;
        })
        // (optionalAttrs plugin.hasCommands {
          inherit (plugin) cmd;
        })
        // (optionalAttrs plugin.hasFileTypes {
          inherit (plugin) ft;
        });
    };
  pluginsLuaDef = plugins:
    with lua; nix2lua (return (foldl' pluginLuaDef {} plugins));
in {
  inherit normalizePlugin;
  inherit normalizePlugins;
  inherit mkSlothFlakePlugin;
  inherit mkRuntimePlugin;
  inherit textOrContent;
}

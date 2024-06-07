{
  pkgs,
  lib,
  vimUtils,
  dependenciesExtraArgs,
  types,
  ...
}: let
  inherit (builtins) foldl' isPath isList isString mapAttrs match elemAt;
  inherit (lib.attrsets) attrNames optionalAttrs;
  inherit (lib.lists) concatMap;
  inherit (lib.strings) fileContents splitString;
  lua = callPackage ./lua.nix {};
  callPackage = lib.callPackageWith (pkgs // dependenciesExtraArgs);

  hasMatch = pattern: str: isList (match pattern str);
  wrapArray = value:
    if isList value
    then value
    else [value];

  defaultPlugin = {
    enabled = true;
    init = null;
    config = null;
    dependencies = [];
    lazy = false;
    cmd = [];
    ft = [];
    events = [];
    keymaps = [];
  };

  remotePluginToNeovimPlugin = p:
    vimUtils.buildVimPlugin rec {
      inherit (p) src name;
      pname = name;
    };

  defaultKeymap = {mode = "n";};
  normalizeKeymap = keymap: let
    value = (
      if isString keymap
      then {mapping = keymap;}
      else keymap
    );
  in
    mapAttrs (_: wrapArray) (defaultKeymap // value);
  normalizeKeymaps = keymaps:
    if isList keymaps
    then map normalizeKeymap keymaps
    else [(normalizeKeymap keymaps)];

  normalizeEvent = event: let
    value =
      if ! isString event
      then event
      else if ! hasMatch ".* .*" event
      then {name = event;}
      else let
        part = elemAt (splitString " " event);
      in {
        name = part 0;
        pattern = part 1;
      };
  in
    mapAttrs (_: wrapArray) value;
  normalizeEvents = events:
    if isList events
    then map normalizeEvent events
    else [(normalizeEvent events)];

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
        then dep // {plugin = remotePluginToNeovimPlugin plugin;}
        else dep;
    p = withPluginDefaults plugin;
  in
    p
    // rec {
      hasCommands = p.cmd != [];
      hasFileTypes = p.ft != [];
      keymaps = normalizeKeymaps p.keymaps;
      hasKeymaps = p.keymaps != [];
      events = normalizeEvents p.events;
      hasEvents = p.events != [];
      lazy = p.lazy || hasCommands || hasFileTypes || hasEvents || hasKeymaps;
      optional = lazy || p.init != null;
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
        mv *.lua $dir
        for d in *; do
          if [[ -d "$d" ]] && [[ "$d" != 'lua' ]]; then
            mv "$d" $dir
          fi
        done

        cat <<'LUA' > $dir/dependencies.lua
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
        })
        // (optionalAttrs plugin.hasEvents {
          inherit (plugin) events;
        })
        // (optionalAttrs plugin.hasKeymaps {
          inherit (plugin) keymaps;
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

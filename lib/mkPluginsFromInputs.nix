{
  pkgs,
  inputs,
  predicate ? pkgs.lib.strings.hasPrefix "plugin-",
  nameMap ? builtins.substring 7 (-1),
  buildVimPlugin ? pkgs.vimUtils.buildVimPlugin,
}: let
  inherit (builtins) attrNames filter foldl' mapAttrs;
  names = filter predicate (attrNames inputs);
  mkPlugin = m: k: let
    name = nameMap k;
    pluginDef = {
      inherit name;
      src = inputs.${k};
    };
  in
    m // {${name} = pluginDef;};
  plugins = foldl' mkPlugin {} names;
in
  mapAttrs (_: buildVimPlugin) plugins

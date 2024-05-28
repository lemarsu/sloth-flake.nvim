{lib, ...}: let
  inherit (lib.strings) removeSuffix;
  inherit (builtins) match;
  handleAst = data: let
    ast = data.__ast;
  in
    if ast == "raw"
    then data.data
    else if ast == "return"
    # TODO nix2lua can return null
    then "return ${nix2lua data.data}"
    else if ast == "fn"
    then "function ${data.name}()\n${nix2lua data.data}\nend"
    else abort ''Unknown ast type ${ast.__ast}'';

  nix2lua = data: let
    inherit (builtins) isInt isBool isNull isString isList isPath isAttrs isFunction typeOf concatStringsSep attrNames concatMap;
    type = typeOf data;
    condValue2list = val: value:
      if isNull val
      then []
      else [value];
    value2list = val: condValue2list val val;
  in
    if data ? __ast
    then handleAst data
    else if isInt data
    then toString data
    else if isBool data
    then
      if data
      then "true"
      else "false"
    else if isString data || isPath data
    then ''"${data}"''
    else if isNull data
    then "nil"
    else if isFunction data
    then (builtins.trace "Skipping function" null)
    else if isList data
    then let
      nix2luaList = val: value2list (nix2lua val);
      listContent = concatStringsSep ", " (concatMap nix2luaList data);
    in "{ ${listContent} }"
    else if isAttrs data
    then let
      mkKeyValue = key: let
        value = data.${key};
        luaKey =
          if isNull (match "[a-zA-Z_][a-zA-Z_0-9]+" key)
          then ''["${key}"]''
          else key;
        luaValue = nix2lua value;
      in
        # TODO Handle indentifier keys
        condValue2list luaValue ''
          ${luaKey} = ${luaValue},
        '';
      attrsContent = concatMap mkKeyValue (attrNames data);
    in ''
      {
        ${concatStringsSep "" attrsContent}}
    ''
    else abort ''Type "${type}"'';
in rec {
  inherit nix2lua;

  wrapFunction = content: "function()\n${content}\nend";
  wrapReturnFunction = content: "return ${wrapFunction content}";
  wrapSelfInvokingFunction = {
    section,
    lua,
  }: ''
    -- begin ${section}
    (${wrapFunction (removeSuffix "\n" lua)})();
    -- end ${section}
  '';

  raw = data: {
    inherit data;
    __ast = "raw";
  };

  function = name: data: {
    inherit name data;
    __ast = "fn";
  };

  lambda = function "";

  return = data: {
    inherit data;
    __ast = "return";
  };
}

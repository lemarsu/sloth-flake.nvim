{...}: let
  inherit (builtins) match isNull typeOf concatStringsSep attrNames concatMap;

  commaJoin = concatStringsSep ", ";
  wrapNotNull' = val: value:
    if isNull val
    then []
    else [value];
  wrapNotNull = val: wrapNotNull' val val;

  toLua = {
    ast = {
      raw = {data, ...}: data;
      return = {data, ...}: "return ${nix2lua data}";
      fn = {
        data,
        name,
        args,
        ...
      }: "function ${name}(${commaJoin args})\n${nix2lua data}\nend";
    };

    type = rec {
      null = _: "nil";
      string = data: ''"${data}"'';
      path = string;
      lambda = data: builtins.trace "Skipping function" null;
      int = data: toString data;

      bool = data:
        if data
        then "true"
        else "false";

      ast = data: let
        astType = data.__ast;
      in
        if toLua.ast ? ${astType}
        then toLua.ast.${astType} data
        else abort ''Unknown ast type ${astType}'';

      list = data: let
        nix2luaList = val: wrapNotNull (nix2lua val);
        listContent = commaJoin (concatMap nix2luaList data);
      in "{ ${listContent} }";

      set = data: let
        mkKeyValue = key: let
          value = data.${key};
          luaKey =
            if isNull (match "[a-zA-Z_][a-zA-Z_0-9]+" key)
            then ''["${key}"]''
            else key;
          luaValue = nix2lua value;
        in
          wrapNotNull' luaValue ''
            ${luaKey} = ${luaValue},
          '';
        attrsContent = concatMap mkKeyValue (attrNames data);
      in ''
        {
          ${concatStringsSep "" attrsContent}}
      '';
    };
  };

  newAst = type: set: set // {__ast = type;};

  nix2lua = data: let
    type = typeOf data;
  in
    if data ? __ast
    then toLua.type.ast data
    else if toLua.type ? ${type}
    then toLua.type.${type} data
    else abort ''Type "${type}"'';
in rec {
  inherit nix2lua;

  raw = data: newAst "raw" {inherit data;};

  functionWithArgs = name: args: data:
    newAst "fn" {
      inherit name data args;
    };

  function = name: data: functionWithArgs name [] data;

  lambda = function "";

  return = data: newAst "return" {inherit data;};
}

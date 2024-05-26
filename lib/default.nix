{version, yants}: let
  types = import ./types.nix {inherit yants;};
in {
  mkNeovimPkg = import ./mkNeovimPkg.nix {inherit version types;};

  sourcesWith = path: paths: let
    samePath = a: let a' = builtins.toString a; in b: a' == builtins.toString b;
    isRoot = samePath "/";
    isInPath = path: subPath:
      if isRoot subPath
      then false
      else (samePath path subPath) || (isInPath path (builtins.dirOf subPath));
    filter = src: _type: builtins.any (includePath: isInPath includePath src) paths;
  in
    builtins.path {
      inherit path filter;
    };
}

{
  formatter,
  nil,
  pkgs,
  ...
}:
with pkgs;
  mkShell {
    buildInputs = [
      formatter
      git-cliff
      nil
      sumneko-lua-language-server
    ];
  }

{
  pkgs,
  nil,
  ...
}:
with pkgs;
  mkShell {
    buildInputs = [
      nil
      sumneko-lua-language-server
    ];
  }

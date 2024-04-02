{
  pkgs,
  nil,
  ...
}:
with pkgs;
  mkShell {
    buildInputs = [
      neovim
      nil
      sumneko-lua-language-server
    ];
  }

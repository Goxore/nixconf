{inputs, ...}: {
  perSystem = {pkgs, ...}: let
  in {
    packages.neovim = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.neovim;
      runtimeInputs = [
        pkgs.clang
        pkgs.gcc
        pkgs.pkg-config
        pkgs.manix
        pkgs.statix
        pkgs.nixd
        pkgs.alejandra
        pkgs.lua-language-server
      ];
      env = {
        SHELL = "fish";
      };
    };
  };
}

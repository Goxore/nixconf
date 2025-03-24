{
  lib,
  clang,
  gcc,
  pkg-config,
  manix,
  statix,
  neovim,
  nixd,
  lua-language-server,
  lf,
  alejandra,
}: let
  packages = [
    clang
    gcc
    pkg-config
    lf
    manix
    statix
    nixd
    alejandra
    lua-language-server
  ];
in
  neovim.overrideAttrs (oldAttrs: {
    postFixup =
      (oldAttrs.postFixup or "")
      + ''
        wrapProgram $out/bin/nvim \
        --suffix PATH : "${lib.makeBinPath packages}"
      '';
  })

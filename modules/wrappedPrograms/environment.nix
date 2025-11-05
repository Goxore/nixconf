{
  lib,
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    self',
    ...
  }: let
    inherit
      (lib)
      getExe
      ;
  in {
    packages.environment = inputs.wrappers.lib.makeWrapper {
      inherit pkgs;
      package = self'.packages.fish;
      runtimeInputs = [
        # nix
        pkgs.nil
        pkgs.nixd
        pkgs.statix
        pkgs.alejandra
        pkgs.manix
        pkgs.nix-inspect
        self'.packages.nh

        # other
        pkgs.file
        pkgs.unzip
        pkgs.zip
        pkgs.p7zip
        pkgs.wget
        pkgs.killall
        pkgs.sshfs
        pkgs.fzf
        pkgs.htop
        pkgs.btop
        pkgs.eza
        pkgs.fd
        pkgs.zoxide
        pkgs.dust
        pkgs.ripgrep
        pkgs.neofetch
        pkgs.tree-sitter
        pkgs.imagemagick
        pkgs.imv
        pkgs.ffmpeg
        pkgs.yt-dlp
        pkgs.lazygit
        pkgs.jujutsu
        pkgs.jjui

        # wrapped
        self'.packages.neovim
        self'.packages.qalc
        self'.packages.lf
        self'.packages.git
      ];
      env = {
        EDITOR = "${getExe self'.packages.neovim}";
      };
    };
  };
}

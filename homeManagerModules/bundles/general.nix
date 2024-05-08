{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    # inputs.stylix.homeManagerModules.stylix
  ];

  nixpkgs = {
    config = {
      # allowUnfree = true;
      experimental-features = "nix-command flakes";
    };
  };

  myHomeManager.zsh.enable = lib.mkDefault true;
  myHomeManager.fish.enable = lib.mkDefault true;
  myHomeManager.lf.enable = lib.mkDefault true;
  myHomeManager.yazi.enable = lib.mkDefault true;
  myHomeManager.nix-extra.enable = lib.mkDefault true;
  # myHomeManager.bottom.enable = lib.mkDefault true;
  myHomeManager.btop.enable = lib.mkDefault true;
  myHomeManager.nix-direnv.enable = lib.mkDefault true;
  myHomeManager.nix.enable = lib.mkDefault true;
  myHomeManager.git.enable = lib.mkDefault true;

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    nil
    # nixd
    pistol
    file
    git
    p7zip
    unzip
    zip
    stow
    libqalculate
    imagemagick
    killall
    neovim

    fzf
    htop
    lf
    eza
    fd
    zoxide
    bat
    du-dust
    ripgrep
    neofetch
    lazygit

    ffmpeg
    wget

    yt-dlp
    tree-sitter

    nh
  ];

  home.sessionVariables = {
    FLAKE = "${config.home.homeDirectory}/nixconf";
  };

  myHomeManager.impermanence.data.directories = [
    ".ssh"
  ];

  myHomeManager.impermanence.cache.directories = [
    ".local/share/nvim"
    ".config/nvim"
  ];

  myHomeManager.impermanence.cache.files = [
    ".zsh_history"
  ];
}

{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: {
  nixpkgs = {
    config = {
      experimental-features = "nix-command flakes";
    };
  };

  myHomeManager.zsh.enable = lib.mkDefault true;
  myHomeManager.fish.enable = lib.mkDefault true;
  myHomeManager.lf.enable = lib.mkDefault true;
  myHomeManager.yazi.enable = lib.mkDefault true;
  myHomeManager.nix-extra.enable = lib.mkDefault true;
  myHomeManager.btop.enable = lib.mkDefault true;
  myHomeManager.nix-direnv.enable = lib.mkDefault true;
  myHomeManager.nix.enable = lib.mkDefault true;
  myHomeManager.git.enable = lib.mkDefault true;
  myHomeManager.virt-manager.enable = lib.mkDefault true;

  myHomeManager.stylix.enable = lib.mkDefault true;

  # myHomeManager.bottom.enable = lib.mkDefault true;

  programs.home-manager.enable = true;

  programs.lazygit.enable = true;
  programs.bat.enable = true;

  home.packages = with pkgs; [
    nil

    pistol
    file
    git
    p7zip
    unzip
    zip
    libqalculate
    imagemagick
    killall
    nvimWithDeps

    fzf
    htop
    lf
    eza
    fd
    zoxide
    du-dust
    ripgrep
    neofetch
    imv

    ffmpeg
    wget

    yt-dlp
    tree-sitter

    nh

    sshfs
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

{ pkgs, lib, inputs, modulesPath, ... }: {
  imports = [
    # "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"

  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";


  environment.systemPackages = with pkgs; [
    neovim
    disko
    parted
    git
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.hyprland.enable = true;

  # boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];
  # boot.supportedFilesystems = [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];
}

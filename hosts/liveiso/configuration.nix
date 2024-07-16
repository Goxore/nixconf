{
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  myNixOS = {
    bundles.users.enable = true;
    stylix.enable = lib.mkDefault true;

    home-users = {
      "yurii" = {
        userConfig = ./home.nix;
        userSettings = {
          extraGroups = ["networkmanager" "wheel" "adbusers"];
        };
      };
    };
  };

  networking.firewall.enable = false;
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    disko
    parted
    git
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];
}

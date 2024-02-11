{
  config,
  pkgs,
  lib,
  inputs,
  outputs,
  system,
  myLib,
  ...
}: {
  imports =
    [
      ./hardware-configuration.nix
      (import ./disko.nix {device = "/dev/nvme1n1";})
      inputs.disko.nixosModules.default
    ]
    ++ (myLib.filesIn ./included);

  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.home-manager.enable = true;
    power-management.enable = true;
    sops.enable = false;

    virtualisation.enable = lib.mkDefaut true;

    sharedSettings.hyprland.enable = true;
    userName = "yurii";
    userConfig = ./home.nix;
    userNixosSettings = {
      extraGroups = ["networkmanager" "wheel" "libvirtd" "docker" "adbusers" "openrazer"];
    };
  };

  programs.hyprland.package = inputs.hyprland.packages."${pkgs.system}".hyprland;
  security.polkit.enable = true;

  virtualisation.libvirtd.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings = {
      dns_enabled = true;
    };
  };

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  hardware = {
    enableAllFirmware = true;
    cpu.amd.updateMicrocode = true; #needs unfree
    bluetooth.enable = true;
    opengl = {
      enable = true;
      driSupport32Bit = true;
      driSupport = true;
    };
  };

  hardware.openrazer.enable = true;

  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
  xdg.portal.enable = true;

  services.xserver = {
    enable = true;
    videoDrivers = ["modesetting" "nvidia"];
    layout = "us";
    xkbVariant = "";
    libinput.enable = true;

    displayManager = {
      defaultSession = "hyprland";
    };
  };

  services = {
    hardware.openrgb.enable = true;
    flatpak.enable = true;
    udisks2.enable = true;
    printing.enable = true;
  };

  programs.noisetorch.enable = true;
  programs.kdeconnect.enable = true;
  programs.zsh.enable = true;
  programs.hyprland.enable = true;
  programs.adb.enable = true;

  environment.systemPackages = with pkgs; [
    wineWowPackages.stable
    wineWowPackages.waylandFull
    winetricks
  ];

  system.stateVersion = "23.11";
}

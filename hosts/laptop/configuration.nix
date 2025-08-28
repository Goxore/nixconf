{
  config,
  pkgs,
  lib,
  inputs,
  outputs,
  myLib,
  ...
}: {
  imports =
    [
      ./hardware-configuration.nix
      (import ./disko.nix {device = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S736NU0W100374K";})

      inputs.disko.nixosModules.default
    ]
    ++ (myLib.filesIn ./included);

  programs.corectrl.enable = true;

  nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];

  home-manager.backupFileExtension = ".backup";

  boot = {
    loader.grub.enable = true;
    loader.grub.efiSupport = true;
    loader.grub.efiInstallAsRemovable = true;

    supportedFilesystems.ntfs = true;

    kernelParams = ["quiet" "amd_pstate=guided" "processor.max_cstate=1"];
    kernelModules = ["coretemp" "cpuid" "v4l2loopback"];
  };

  boot.plymouth.enable = true;

  services.xserver.videoDrivers = ["amdgpu"];
  boot.initrd.kernelModules = ["amdgpu"];

  myNixOS = {
    gaming.enable = true;
    bundles.general-desktop.enable = true;
    hyprland.enable = true;
    power-management.enable = true;

    virtualisation.enable = lib.mkDefaut true;

    bundles.users.enable = true;
    home-users = {
      "yurii" = {
        userConfig = ./home.nix;
        userSettings = {
          extraGroups = ["networkmanager" "wheel" "libvirtd" "docker" "adbusers" "openrazer"];
          hashedPasswordFile = "/persist/passwd";
        };
      };
    };

    impermanence.enable = true;
    # impermanence.nukeRoot.enable = true;
  };

  networking = {
    hostName = "laptop";
    networkmanager.enable = true;
    firewall.enable = false;
  };

  virtualisation.libvirtd.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings = {
      dns_enabled = true;
    };
  };

  hardware.cpu.amd.updateMicrocode = true;

  services = {
    hardware.openrgb.enable = true;
    flatpak.enable = true;
    udisks2.enable = true;
    printing.enable = true;
  };

  programs.adb.enable = true;

  programs.alvr.enable = true;
  programs.alvr.openFirewall = true;

  environment.systemPackages = with pkgs; [
    wineWowPackages.stable
    wineWowPackages.waylandFull
    winetricks
    glib

    bs-manager
  ];

  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
  xdg.portal.enable = true;

  hardware.graphics.enable = true;

  programs.niri.enable = true;

  system.stateVersion = "23.11";
}

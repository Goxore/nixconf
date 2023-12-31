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
      outputs.nixosModules.default

      ./hardware-configuration.nix
    ]
    ++ (myLib.filesIn ./included);

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.home-manager.enable = true;
    power-management.enable = true;
    sops.enable = true;

    virtualisation.enable = lib.mkDefaut true;

    sharedSettings.hyprland.enable = true;
    userName = "yurii";
    userConfig = ./home.nix;
    userNixosSettings = {
      extraGroups = ["networkmanager" "wheel" "libvirtd" "docker" "adbusers" "openrazer"];
    };
  };

  programs.hyprland.package = inputs.hyprland.packages."${pkgs.system}".hyprland;

  boot = {
    loader.systemd-boot.enable = true;

    # silent boot
    initrd.verbose = false;
    consoleLogLevel = 0;
    kernelParams = ["quiet" "udev.log_level=3" "nvidia_drm.fbdev=1" "nvidia_drm.modeset=1"];

    # loader.grub.enable = true;
    # loader.grub.useOSProber = true;
    loader.efi.canTouchEfiVariables = true;
    loader.efi.efiSysMountPoint = "/boot/efi";

    supportedFilesystems = ["ntfs"];

    kernelModules = ["coretemp" "cpuid" "v4l2loopback"];
  };

  security.polkit.enable = true;

  virtualisation.podman = {
    enable = true;

    # Create a `docker` alias for podman, to use it as a drop-in replacement
    dockerCompat = true;

    # Required for containers under podman-compose to be able to talk to each other.
    # defaultNetwork.dnsname.enable = true;
    # For Nixos version > 22.11
    defaultNetwork.settings = {
      dns_enabled = true;
    };
  };
  virtualisation.libvirtd.enable = true;

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

  # Services
  services = {
    hardware.openrgb.enable = true;
    flatpak.enable = true;
    udisks2.enable = true;
    printing.enable = true;
  };

  # # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.yurii = {
  #   isNormalUser = true;
  #   description = "yurii";
  #   shell = pkgs.zsh;
  #   extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" "adbusers" "openrazer" ];
  # };

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

  # ================================================================ #
  # =                         DO NOT TOUCH                         = #
  # ================================================================ #

  system.stateVersion = "22.11";
}

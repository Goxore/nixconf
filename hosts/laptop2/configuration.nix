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

  boot = {
    loader.grub.enable = true;
    loader.grub.efiSupport = true;
    loader.grub.efiInstallAsRemovable = true;

    supportedFilesystems = ["ntfs"];

    # loader.systemd-boot.enable = true;
    kernelParams = ["quiet" "udev.log_level=3" "nvidia_drm.fbdev=1" "nvidia_drm.modeset=1"];
    kernelModules = ["coretemp" "cpuid" "v4l2loopback"];
  };

  myNixOS = {
    bundles.general-desktop.enable = true;
    # bundles.home-manager.enable = true;
    bundles.users.enable = true;
    power-management.enable = true;
    sops.enable = false;

    virtualisation.enable = lib.mkDefaut true;

    sharedSettings.hyprland.enable = true;

    home-users = {
      "yurii" = {
        userConfig = ./home.nix;
        userSettings = {
          extraGroups = ["networkmanager" "wheel" "libvirtd" "docker" "adbusers" "openrazer"];
        };
      };
    };

    impermanence.enable = true;
    impermanence.nukeRoot.enable = true;
  };

  # programs.hyprland.package = inputs.hyprland.packages."${pkgs.system}".hyprland;
  security.polkit.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;

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
  networking.firewall.enable = false;

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

  environment.pathsToLink = [ "/libexec" ]; # links /libexec from derivations to /run/current-system/sw 
  services.xserver = {
    enable = true;
    videoDrivers = ["modesetting" "nvidia"];
    layout = "us";
    xkbVariant = "";
    libinput.enable = true;

    displayManager = {
      defaultSession = "hyprland";
      startx.enable = true;
    };

    windowManager.awesome = {
      enable = true;
      luaModules = with pkgs.luaPackages; [
        luarocks # is the package manager for Lua modules
        luadbi-mysql # Database abstraction layer
      ];
    };

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        dmenu #application launcher most people use
        i3status # gives you the default i3 status bar
        i3lock #default i3 screen locker
        i3blocks #if you are planning on using i3blocks over i3status
      ];
    };

  };

  services = {
    hardware.openrgb.enable = true;
    flatpak.enable = true;
    udisks2.enable = true;
    printing.enable = true;
  };

  # programs.noisetorch.enable = true;
  # programs.kdeconnect.enable = false;
  programs.zsh.enable = true;
  programs.hyprland.enable = true;
  programs.adb.enable = true;

  environment.systemPackages = with pkgs; [
    wineWowPackages.stable
    wineWowPackages.waylandFull
    winetricks
  ];

  specialisation.primary.configuration = {
    xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
    xdg.portal.enable = true;
  };

  specialisation.gnome.configuration = {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.displayManager.sddm.enable = false;
    services.xserver.desktopManager.gnome.enable = true;

    hardware.pulseaudio.enable = false;

    environment.gnome.excludePackages = (with pkgs; [
      gnome-photos
      gnome-tour
      gedit
    ]) ++ (with pkgs.gnome; [
      cheese # webcam tool
      gnome-music
      gnome-terminal
      epiphany # web browser
      geary # email reader
      evince # document viewer
      gnome-characters
      totem # video player
      tali # poker game
      iagno # go game
      hitori # sudoku game
      atomix # puzzle game
    ]);
  };

  system.stateVersion = "23.11";
}

{
  config,
  pkgs,
  lib,
  inputs,
  outputs,
  system,
  myLib,
  hm,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users.enable = true;
    sddm.enable = true;

    hyprland.enable = true;
    home-users = {
      "yurii" = {
        userConfig = ./home.nix;
        userSettings = {
          extraGroups = ["docker" "libvirtd" "networkmanager" "wheel" "adbusers"];
        };
      };
    };
  };

  system.name = "work-nixos";
  system.nixos.label = "test1";

  security.sudo.wheelNeedsPassword = false;

  # boot.loader.systemd-boot.enable = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.useOSProber = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
    options kvm_intel emulate_invalid_guest_state=0
    options kvm ignore_msrs=1
  '';

  networking.hostName = "work";

  # Enable networking
  networking.networkmanager.enable = true;

  services.xserver = {
    enable = true;
    # videoDrivers = ["nvidia"];
    videoDrivers = ["amdgpu"];
    layout = "us";
    xkbVariant = "";
    libinput.enable = true;
  };

  hardware = {
    enableAllFirmware = true;
    cpu.amd.updateMicrocode = true;
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
    opengl = {
      enable = true;
      driSupport32Bit = true;
      # driSupport = true;
      extraPackages = with pkgs; [
        vulkan-tools
        vulkan-headers
        vulkan-loader
        vulkan-validation-layers
        vulkan-tools-lunarg
      ];
    };
  };

  # hardware.nvidia.modesetting.enable = true;
  # environment.variables.WLR_NO_HARDWARE_CURSORS = "1";

  services.printing.enable = true;
  services.ratbagd.enable = true;
  services.usbmuxd.enable = true;
  services.avahi.enable = true;

  environment.systemPackages = with pkgs; [
    pciutils
    cifs-utils
    vulkan-tools
  ];

  networking.firewall.allowedTCPPorts = [50000 53962 51319 32771 40668 54156 8080 80 50922 5000 3000];
  networking.firewall.allowedUDPPorts = [50000 56787 51319 32771 40668 38396 46223 8080 80 50922 5000 3000];
  networking.firewall.extraCommands = ''iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns'';
  networking.firewall.enable = false;
  services.samba-wsdd.enable = true;

  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
  xdg.portal.enable = true;

  programs.adb.enable = true;

  virtualisation = {
    # podman = {
    #   enable = true;
    #
    #   # `docker` alias
    #   dockerCompat = true;
    #   defaultNetwork.settings.dns_enabled = true;
    # };
  };
  virtualisation.libvirtd.enable = true;
  virtualisation.docker.enable = true;
  # virtualisation.docker.enableNvidia = true;

  services.gnome.gnome-keyring.enable = true;
  services.gvfs.enable = true;
  services.flatpak.enable = true;

  services.samba = {
    enable = true;
  };

  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
  ];

  boot.supportedFilesystems.ntfs = true;

  fileSystems."/mnt/nvme" = {
    device = "/dev/nvme0n1p3";
    fsType = "ntfs-3g";
    options = ["rw" "uid=1000"];
  };

  services.openssh.enable = true;

  # ================================================================ #
  # =                         DO NOT TOUCH                         = #
  # ================================================================ #

  system.stateVersion = "23.05";
}

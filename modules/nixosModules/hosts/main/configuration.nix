{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.main = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.hostMain
    ];
  };

  flake.nixosModules.hostMain = {pkgs, ...}: {
    imports = [
      self.nixosModules.base
      self.nixosModules.general
      self.nixosModules.desktop

      self.nixosModules.impermanence

      self.nixosModules.discord
      self.nixosModules.gimp
      self.nixosModules.hyprland
      self.nixosModules.telegram
      self.nixosModules.youtube-music

      self.nixosModules.gaming
      self.nixosModules.vr
      self.nixosModules.powersave

      # disko
      inputs.disko.nixosModules.disko
      self.diskoConfigurations.hostMain
    ];

    programs.corectrl.enable = true;

    boot = {
      loader.grub.enable = true;
      loader.grub.efiSupport = true;
      loader.grub.efiInstallAsRemovable = true;

      supportedFilesystems.ntfs = true;

      # kernelParams = ["quiet" "amd_pstate=guided" "processor.max_cstate=1"];
      kernelParams = ["quiet"];
      kernelModules = ["coretemp" "cpuid" "v4l2loopback"];
    };

    boot.plymouth.enable = true;

    networking = {
      hostName = "main";
      networkmanager.enable = true;
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

      zerotierone
    ];

    xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
    xdg.portal.enable = true;

    hardware.graphics.enable = true;

    programs.niri.enable = true;

    networking.firewall.enable = false;
    programs.appimage.enable = true;
    programs.appimage.binfmt = true;

    services.xserver.videoDrivers = ["amdgpu"];
    boot.initrd.kernelModules = ["amdgpu"];

    # services.create_ap = {
    #   enable = true;
    #   settings = {
    #     INTERNET_IFACE = "enp14s0";
    #     WIFI_IFACE = "wlp15s0";
    #     SSID = "TROJANVIRUS67";
    #     PASSPHRASE = "yuriiyuriiyurii";
    #
    #     FREQ_BAND = "5"; # 5GHz
    #     COUNTRY = "UA";
    #     CHANNEL = "36"; # Channel 36
    #     IEEE80211N = "1"; # WiFi 4
    #     IEEE80211AC = "1"; # WiFi 5
    #     IEEE80211AX = "1"; # WiFi 6 (HE)
    #     HT_CAPAB = "[HT40+]"; # 40MHz
    #   };
    # };
    #
    # # no conflicts
    # networking.networkmanager.unmanaged = ["wlp15s0"];
    # # speed
    # networking.firewall.allowedUDPPorts = [53 67];

    system.stateVersion = "23.11";
  };
}

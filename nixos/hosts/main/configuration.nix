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

  flake.nixosModules.hostMain = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      self.nixosModules.base
      self.nixosModules.general
      self.nixosModules.desktop

      self.nixosModules.impermanence

      self.nixosModules.discord
      self.nixosModules.gimp
      self.nixosModules.telegram
      self.nixosModules.youtube-music

      self.nixosModules.gaming
      self.nixosModules.vr
      self.nixosModules.powersave

      self.nixosModules.virt

      # disko
      inputs.disko.nixosModules.disko
      self.diskoConfigurations.hostMain
    ];

    programs.corectrl.enable = true;

    boot = {
      kernelPackages = pkgs.linuxPackages_latest;

      loader.grub.enable = true;
      loader.grub.efiSupport = true;
      loader.grub.efiInstallAsRemovable = true;

      supportedFilesystems.ntfs = true;

      # kernelParams = ["quiet" "amd_pstate=guided" "processor.max_cstate=1"];
      kernelParams = ["quiet"];
      kernelModules = ["mt7921e" "coretemp" "cpuid" "v4l2loopback"];

      binfmt.emulatedSystems = ["aarch64-linux"];
    };

    boot.plymouth.enable = true;

    networking = {
      hostName = "main";
      networkmanager.enable = true;
    };

    hardware.cpu.amd.updateMicrocode = true;

    services = {
      hardware.openrgb.enable = true;
      flatpak.enable = true;
      udisks2.enable = true;
      printing.enable = true;
    };

    programs.alvr.enable = true;
    programs.alvr.openFirewall = true;

    environment.systemPackages = with pkgs; [
      winetricks
      glib

      bs-manager

      zerotierone

      android-tools
      self.packages."${pkgs.stdenv.hostPlatform.system}".ask
      (rustPlatform.buildRustPackage
        (finalAttrs: {
          pname = "repeater";
          version = "v0.1.10";

          src = fetchFromGitHub {
            owner = "shaankhosla";
            repo = "repeater";
            tag = finalAttrs.version;
            hash = "sha256-8TWqY78w5cOirLnrBONiratAZQSQrYpp++5dXRlFlNo=";
          };

          cargoHash = "sha256-hngZ55o1YsnstBGjp8++9SsxwfUyu+X4YwZuzMupFTE=";
        }))
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

    programs.obs-studio = {
      enable = true;
      plugins = with pkgs.obs-studio-plugins; [
        obs-move-transition
      ];
    };
    persistance.cache.directories = [
      ".config/obs-studio"
    ];

    services.create_ap = {
      enable = true;
      settings = {
        INTERNET_IFACE = "enp14s0";
        WIFI_IFACE = "wlp15s0";
        SSID = "TROJANVIRUS67";
        PASSPHRASE = "yuriiyuriiyurii";

        FREQ_BAND = "5"; # 5GHz
        COUNTRY = "UA";
        CHANNEL = "36"; # Channel 36
        IEEE80211N = "1"; # WiFi 4
        IEEE80211AC = "1"; # WiFi 5
        IEEE80211AX = "1"; # WiFi 6 (HE)
        HT_CAPAB = "[HT40+]"; # 40MHz
      };
    };

    # no conflicts
    networking.networkmanager.unmanaged = ["wlp15s0"];
    # speed
    networking.firewall.allowedUDPPorts = [53 67];

    system.stateVersion = "23.11";
  };
}

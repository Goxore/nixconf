{self, ...}: {
  flake.nixosModules.desktop = {pkgs, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [
      self.nixosModules.gtk

      self.nixosModules.pipewire
      self.nixosModules.firefox
      self.nixosModules.chromium
    ];

    persistance.cache.directories = [
      ".local/state/quickshell"
    ];

    programs.niri.enable = true;
    programs.niri.package = selfpkgs.niri;

    programs.mangowc.enable = true;
    programs.mangowc.package = selfpkgs.mangowc;


    environment.systemPackages = [
      selfpkgs.terminal
      pkgs.pcmanfm
      selfpkgs.vjshell
      pkgs.wl-clipboard
      pkgs.mpv
      pkgs.nixos-icons
    ];

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      ubuntu-sans
      cm_unicode
      corefonts
      unifont
      material-symbols
    ];

    fonts.fontconfig.defaultFonts = {
      serif = ["Ubuntu Sans"];
      sansSerif = ["Ubuntu Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
    };

    time.timeZone = "Europe/Kyiv";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "uk_UA.UTF-8";
      LC_IDENTIFICATION = "uk_UA.UTF-8";
      LC_MEASUREMENT = "uk_UA.UTF-8";
      LC_MONETARY = "uk_UA.UTF-8";
      LC_NAME = "uk_UA.UTF-8";
      LC_NUMERIC = "uk_UA.UTF-8";
      LC_PAPER = "uk_UA.UTF-8";
      LC_TELEPHONE = "uk_UA.UTF-8";
      LC_TIME = "uk_UA.UTF-8";
    };

    services.upower.enable = true;

    security.polkit.enable = true;

    hardware = {
      enableAllFirmware = true;

      bluetooth.enable = true;
      bluetooth.powerOnBoot = true;

      opengl = {
        enable = true;
        driSupport32Bit = true;
      };
    };
  };
}

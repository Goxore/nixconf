{self, ...}: {
  flake.nixosModules.desktop = {pkgs, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";

    inherit (self) themeNoHash;
  in {
    imports = [
      self.nixosModules.gtk

      self.nixosModules.pipewire
      self.nixosModules.firefox
      self.nixosModules.chromium
    ];

    console.colors = with themeNoHash; [
      base00
      base08
      base0B
      base0A
      base0D
      base0E
      base0C
      base05
      base03
      base08
      base0B
      base0A
      base0D
      base0E
      base0C
      base07
    ];

    qt = {
      enable = true;
      platformTheme = "gtk2";
      style = "gtk2";
    };

    persistance.cache.directories = [
      ".local/state/quickshell"
    ];

    programs.mangowc.enable = true;
    programs.mangowc.package = selfpkgs.mangowcDynamic;


    environment.systemPackages = [
      selfpkgs.terminal
      pkgs.pcmanfm
      selfpkgs.vjshell
      pkgs.wl-clipboard
      pkgs.mpv
    ];

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      ubuntu-sans
      cm_unicode
      corefonts
      unifont
      material-symbols
      noto-fonts-color-emoji
    ];

    fonts.fontconfig.defaultFonts = {
      serif = ["Ubuntu Sans"];
      sansSerif = ["Ubuntu Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
      emoji = ["Noto Color Emoji"];
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

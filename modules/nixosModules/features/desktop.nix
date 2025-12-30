{self, ...}: {
  flake.nixosModules.desktop = {
    pkgs,
    lib,
    ...
  }: let
    inherit (lib) getExe;
    selfpkgs = self.packages."${pkgs.system}";
  in {
    imports = [
      self.nixosModules.gtk
      self.nixosModules.wallpaper

      self.nixosModules.pipewire
      self.nixosModules.firefox
      self.nixosModules.chromium
    ];

    # preferences.autostart = [selfpkgs.quickshellWrapped];
    preferences.autostart = [selfpkgs.start-noctalia-shell];

    environment.systemPackages = [
      selfpkgs.terminal
      pkgs.pcmanfm
      selfpkgs.noctalia-bundle
    ];

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      cm_unicode
      corefonts
      unifont
    ];

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

    preferences.keymap = {
      "SUPERCONTROL + S".exec = ''
        ${getExe pkgs.grim} -l 0 - | ${pkgs.wl-clipboard}/bin/wl-copy'';

      "SUPERSHIFT + E".exec = ''
        ${pkgs.wl-clipboard}/bin/wl-paste | ${getExe pkgs.swappy} -f -
      '';

      "SUPERSHIFT + S".exec = ''
        ${getExe pkgs.grim} -g "$(${getExe pkgs.slurp} -w 0)" - \
        | ${pkgs.wl-clipboard}/bin/wl-copy
      '';

      # "SUPER + d"."b".package = pkgs.rofi-bluetooth;
      "SUPER + d"."b".exec = ''
        ${getExe self.packages.${pkgs.system}.noctalia-shell} ipc call bluetooth togglePanel
      '';
    };
  };
}

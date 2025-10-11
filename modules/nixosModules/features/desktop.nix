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

    preferences.autostart = [selfpkgs.quickshellWrapped];

    environment.systemPackages = [
      selfpkgs.terminal
      pkgs.pcmanfm
    ];

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      cm_unicode
      corefonts
    ];

    time.timeZone = "Europe/Bratislava";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "sk_SK.UTF-8";
      LC_IDENTIFICATION = "sk_SK.UTF-8";
      LC_MEASUREMENT = "sk_SK.UTF-8";
      LC_MONETARY = "sk_SK.UTF-8";
      LC_NAME = "sk_SK.UTF-8";
      LC_NUMERIC = "sk_SK.UTF-8";
      LC_PAPER = "sk_SK.UTF-8";
      LC_TELEPHONE = "sk_SK.UTF-8";
      LC_TIME = "sk_SK.UTF-8";
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

      "SUPER + d"."b".package = pkgs.rofi-bluetooth;
    };
  };
}

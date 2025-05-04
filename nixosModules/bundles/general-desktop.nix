{
  pkgs,
  lib,
  ...
}: {
  myNixOS.sddm.enable = lib.mkDefault false;
  myNixOS.autologin.enable = lib.mkDefault true;
  myNixOS.virtualisation.enable = lib.mkDefault true;
  myNixOS.stylix.enable = lib.mkDefault true;
  myNixOS.virt-manager.enable = lib.mkDefault true;

  # Central European time zone
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

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    cm_unicode
    corefonts
  ];

  # battery
  services.upower.enable = true;

  security.polkit.enable = true;

  hardware = {
    enableAllFirmware = true;

    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;

    opengl = {
      enable = true;
      driSupport32Bit = true;
      # driSupport = true;
    };
  };

  programs.dconf.enable = true;

  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-hyprland];
  xdg.portal.enable = true;

  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = ["graphical-session.target"];
      wants = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
}

{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: {
  config = {
    myHomeManager.zathura.enable = lib.mkDefault true;
    myHomeManager.rofi.enable = lib.mkDefault true;
    myHomeManager.alacritty.enable = lib.mkDefault true;
    myHomeManager.kitty.enable = lib.mkDefault true;
    myHomeManager.xremap.enable = lib.mkDefault false;
    myHomeManager.imv.enable = lib.mkDefault false;

    myHomeManager.gtk.enable = lib.mkDefault true;

    home.file = {
      ".local/share/rofi/rofi-bluetooth".source = "${pkgs.rofi-bluetooth}";
    };

    qt.enable = true;
    qt.platformTheme = "gtk";
    qt.style.name = "adwaita-dark";

    home.sessionVariables = {
      QT_STYLE_OVERRIDE = "adwaita-dark";
    };

    services.udiskie.enable = true;

    xdg.mimeApps.defaultApplications = {
      "application/pdf" = ["zathura.desktop"];
      "image/*" = ["imv.desktop"];
      "video/png" = ["mpv.desktop"];
      "video/jpg" = ["mpv.desktop"];
      "video/*" = ["mpv.desktop"];
    };

    services.mako = {
      enable = true;
      borderRadius = 5;
      borderSize = 2;
      defaultTimeout = 10000;
      layer = "overlay";
    };

    home.packages = with pkgs; [
      feh
      noisetorch
      polkit
      polkit_gnome
      lxsession
      pulsemixer
      pavucontrol
      adwaita-qt
      pcmanfm
      libnotify

      pywal
      ripdrag
      mpv
      sxiv
      zathura

      lm_sensors
      upower

      cm_unicode

      virt-manager

      wezterm
      kitty

      onlyoffice-bin
      easyeffects
      gegl
    ];

    myHomeManager.impermanence.cache.directories = [
      ".local/state/wireplumber"
    ];
  };
}

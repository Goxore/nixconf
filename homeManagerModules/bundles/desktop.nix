{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: {
  myHomeManager.zathura.enable = lib.mkDefault true;
  myHomeManager.rofi.enable = lib.mkDefault true;
  myHomeManager.rbw.enable = lib.mkDefault true;
  myHomeManager.alacritty.enable = lib.mkDefault true;
  myHomeManager.kitty.enable = lib.mkDefault true;
  myHomeManager.xremap.enable = lib.mkDefault true;

  myHomeManager.prism.enable = lib.mkDefault true;
  myHomeManager.telegram.enable = lib.mkDefault true;

  myHomeManager.gtk.enable = lib.mkDefault true;

  home.file = {
    ".local/share/rofi/rofi-bluetooth".source = "${pkgs.rofi-bluetooth}";

    ".local/share/wal-telegram".source = builtins.fetchGit {
      url = "https://github.com/guillaumeboehm/wal-telegram";
      rev = "47e1a18f6d60d08ebaabbbac4b133a6158bacadd";
    };
  };

  qt.enable = true;
  qt.platformTheme = "gtk";
  qt.style.name = "adwaita-dark";

  home.sessionVariables = {
    QT_STYLE_OVERRIDE = "adwaita-dark";
  };

  services.udiskie.enable = true;

  xdg.mimeApps.defaultApplications = {
    "text/plain" = ["neovide.desktop"];
    "application/pdf" = ["zathura.desktop"];
    "image/*" = ["imv.desktop"];
    "video/png" = ["mpv.desktop"];
    "video/jpg" = ["mpv.desktop"];
    "video/*" = ["mpv.desktop"];
  };

  programs.imv = {
    enable = true;
    settings = {
      options.background = "${config.colorScheme.colors.base00}";
    };
  };

  services.mako = {
    enable = true;
    backgroundColor = "#${config.colorScheme.colors.base01}";
    borderColor = "#${config.colorScheme.colors.base0E}";
    borderRadius = 5;
    borderSize = 2;
    textColor = "#${config.colorScheme.colors.base04}";
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

    flavours
    pywal
    neovide
    ripdrag
    mpv
    sxiv
    zathura

    lm_sensors
    upower

    cm_unicode

    virt-manager
    youtube-music

    wezterm
    kitty

    onlyoffice-bin
    tdesktop
    discord
    vesktop
    easyeffects
    gimp
    gegl
  ];

  myHomeManager.impermanence.directories = [
    ".config/VencordDesktop"
    ".local/state/wireplumber"
  ];
}

{
  pkgs,
  lib,
  ...
}: {
  myHomeManager = {
    bundles.desktop.enable = lib.mkDefault true;

    chromium.enable = lib.mkDefault true;
    gimp.enable = lib.mkDefault true;
    vesktop.enable = lib.mkDefault true;
    telegram.enable = lib.mkDefault true;
    rbw.enable = lib.mkDefault true;
    hyprland.enable = true;
    firefox.enable = true;
  };

  home.packages = with pkgs; [
    youtube-music
    tdesktop
  ];
}

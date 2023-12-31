{
  inputs,
  outputs,
  pkgs,
  lib,
  ...
}: {
  myHomeManager = {
    bundles.general.enable = true;
    bundles.desktop.enable = true;

    firefox.enable = true;
    hyprland.enable = true;

    monitors = [
      {
        name = "DP-1";
        width = 2560;
        height = 1440;
        refreshRate = 164.0;
        x = 0;
        y = 0;
      }
      {
        name = "HDMI-A-1";
        width = 1920;
        height = 1080;
        refreshRate = 60.0;
        x = 2560;
        y = 430;
      }
    ];
  };

  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

  home = {
    stateVersion = "22.11";
    homeDirectory = lib.mkDefault "/home/yurii";
    username = "yurii";

    packages = with pkgs; [
      bottles
      libimobiledevice
      ifuse
      unityhub
    ];
  };
}

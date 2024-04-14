{
  inputs,
  outputs,
  pkgs,
  lib,
  ...
}: {
  imports = [outputs.homeManagerModules.default];

  programs.git.userName = "yurii";
  programs.git.userEmail = "yurii@goxore.com";

  myHomeManager.impermanence.directories = [
    "nixconf"

    "Videos"
    "Documents"
    "Projects"
    
    # minecraft
    ".local/share/PrismLauncher"

    # vr
    ".config/openvr"
  ];

  myHomeManager = {
    bundles.general.enable = true;
    bundles.desktop-full.enable = true;
    bundles.gaming.enable = true;

    firefox.enable = true;
    hyprland.enable = true;
    pipewire.enable = true;
    tenacity.enable = true;
    gimp.enable = true;

    monitors = [
      {
        name = "eDP-2";
        width = 1920;
        height = 1080;
        refreshRate = 144.003006;
        x = 760;
        y = 1440;
      }
      {
        name = "DP-2";
        width = 3440;
        height = 1440;
        refreshRate = 144.001007;
        x = 0;
        y = 0;
      }
    ];

    startupScript = lib.mkAfter ''
      ${pkgs.telegram-desktop}/bin/telegram-desktop &
      ${pkgs.vesktop}/bin/vesktop &
      ${pkgs.firefox}/bin/firefox &
    '';
  };

  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

  wayland.windowManager.hyprland.settings.master.orientation = "center";

  home = {
    username = "yurii";
    homeDirectory = lib.mkDefault "/home/yurii";
    stateVersion = "22.11";

    packages = with pkgs; [
      obs-studio
      wf-recorder
      blender
      prismlauncher
      tidal-hifi
    ];
  };
}

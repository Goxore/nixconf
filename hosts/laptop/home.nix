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

  myHomeManager.impermanence.data.directories = [
    "nixconf"

    "Videos"
    "Documents"
    "Projects"
  ];

  myHomeManager.impermanence.cache.directories = [
    ".local/share/PrismLauncher"
    ".config/openvr"
    ".config/tidal-hifi"
  ];

  programs.foot.enable = true;
  programs.wezterm.enable = true;

  myHomeManager = {
    bundles.general.enable = true;
    bundles.desktop-full.enable = true;
    bundles.gaming.enable = true;

    firefox.enable = true;
    hyprland.enable = true;
    pipewire.enable = true;
    tenacity.enable = true;
    gimp.enable = true;

    monitors = let
      edp = {
        width = 1920;
        height = 1080;
        refreshRate = 144.;
        x = 760;
        y = 1440;
      };
    in {
      "eDP-1" = edp;
      "eDP-2" = edp;
      "DP-2" = {
        width = 3440;
        height = 1440;
        refreshRate = 144.;
        x = 0;
        y = 0;
      };
    };

    workspaces = {
      "2" = {
        monitorId = 0;
        autostart = with pkgs; [
         (lib.getExe firefox)
        ];
      };
      "10" = {
        monitorId = 1;
        autostart =  with pkgs; [
          (lib.getExe telegram-desktop)
          (lib.getExe vesktop)
        ];
      };
    };

  };


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

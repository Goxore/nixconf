{
  inputs,
  outputs,
  pkgs,
  lib,
  ...
}: {
  myHomeManager = {
    bundles.general.enable = true;
    bundles.desktop-full.enable = true;

    monitors = {
      "DP-3" = {
        width = 2560;
        height = 1440;
        refreshRate = 164.;
        # x = 0;
        # y = 0;
        x = 1920;
        y = 100;
      };
      "HDMI-A-1" = {
        width = 1920;
        height = 1080;
        refreshRate = 60.;
        x = 0;
        y = 0;
        # x = 2560;
        # y = 430;
      };
      "DP-1" = {
        width = 1920;
        height = 1080;
        refreshRate = 75.;
        x = 4480;
        y = 300;
        # x = 2560;
        # y = 430;
      };
    };

    startScripts = {
      mpvpaper = pkgs.writeShellScriptBin "mpvpaper" ''
        ${lib.getExe pkgs.mpvpaper} -vs -o "no-audio loop" DP-3 /home/yurii/Documents/wallpaper.mp4 &
        ${lib.getExe pkgs.mpvpaper} -vs -o "no-audio loop" HDMI-A-1 /home/yurii/Documents/wallpaper.mp4 &
      '';
    };

    hyprland.windowanimation = "workspaces, 1, 3, myBezier, fade";

  };

  home = {
    stateVersion = "22.11";
    homeDirectory = lib.mkDefault "/home/yurii";
    username = "yurii";

    packages = with pkgs; [
      bottles
      libimobiledevice
      ifuse
      (unityhub.override
        {
          extraLibs = pkgs:
            with pkgs; [
              openssl_1_1
            ];
        })
    ];
  };

  wayland.windowManager.hyprland.settings.animations.animation = [
    "workspaces, 1, 3, default, slidevert"
  ];
}

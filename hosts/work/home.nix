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
        x = 0;
        y = 0;
      };
      "HDMI-A-1" = {
        width = 1920;
        height = 1080;
        refreshRate = 60.;
        x = 2560;
        y = 430;
      };
    };
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
}

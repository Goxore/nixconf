{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  options = {
    myHomeManager.startScripts = lib.mkOption {
      default = {};
    };

    myHomeManager.startScriptList = lib.mkOption {
      default = null;
    };
  };

  config.myHomeManager = {
    startScripts = {
      nm = pkgs.writeShellScriptBin "nm" ''
        ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator
      '';

      xdg = pkgs.writeShellScriptBin "xdg" ''
        systemctl --user import-environment PATH &
        systemctl --user restart xdg-desktop-portal.service &
      '';

      ags = pkgs.writeShellScriptBin "ags" ''
        ags &
      '';

      swwpaper = pkgs.writeShellScriptBin "swwpaper" ''
        ${pkgs.swww}/bin/swww init &
        sleep 2
        ${pkgs.swww}/bin/swww img ${config.stylix.image} &
      '';
    };
    startScriptList = builtins.attrValues config.myHomeManager.startScripts;
  };
}

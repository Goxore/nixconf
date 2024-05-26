{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.myNixOS.autologin;
in {
  options.myNixOS.autologin = {
    user = lib.mkOption {
      default = null;
      description = ''
        username to autologin
      '';
    };
  };

  # config = lib.mkIf (cfg.user != null) {
  #   services.displayManager.autoLogin = {
  #     enable = true;
  #     services.displayManager.autoLogin.user = cfg.user;
  #   };
  #
  #   services.displayManager.defaultSession = "Hyprland";
  # };

  # config = lib.mkIf (cfg.user != null) {
  #   services.greetd = let
  #     tuigreet = "${pkgs.greetd.tuigreet}/bin/tuigreet";
  #   in {
  #     enable = true;
  #     settings = {
  #       initial_session = {
  #         command = "Hyprland";
  #         user = "${cfg.user}";
  #       };
  #     };
  #   };
  # };
}

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

  config = lib.mkIf (cfg.user != null) {
    programs.bash.shellInit = ''
      if [ "$(tty)" = "/dev/tty1" ]; then
        exec Hyprland &> /dev/null
      fi
    '';
  };
}

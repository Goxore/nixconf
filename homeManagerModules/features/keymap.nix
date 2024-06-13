{
  pkgs,
  lib,
  ...
}:
with pkgs; let
  inherit (lib) getExe;
in {
  myHomeManager.keybinds = {
    "SUPER, d" = {
      "f".package = firefox;
      "t".package = telegram-desktop;
      "s".package = pavucontrol;
      "b".package = rofi-bluetooth;
      "h".script = ''
        ${getExe kitty} -e ${getExe btop}
      '';
    };

    "SUPER, p".script = ''
      ${getExe playerctl} play-pause'';

    "SUPERCONTROL, S".script = ''
      ${getExe grim} -l 0 - | ${wl-clipboard}/bin/wl-copy'';

    "SUPERSHIFT, E".script = ''
      ${wl-clipboard}/bin/wl-paste | ${getExe swappy} -f -
    '';

    "SUPERSHIFT, S".script = ''
      ${getExe grim} -g "$(${getExe slurp} -w 0)" - \
      | ${wl-clipboard}/bin/wl-copy
    '';

    "SUPER, V".script = ''
      amixer sset Capture toggle
    '';
  };
}

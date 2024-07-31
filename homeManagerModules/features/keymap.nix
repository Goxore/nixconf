{
  pkgs,
  lib,
  inputs,
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
      "c".script = ''
        ${getExe kitty} -e ${getExe libqalculate}
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
      ${pkgs.alsa-utils}/bin/amixer sset Capture toggle
    '';

    # output=$(hyprctl -j monitors | ${getExe jq} -r '.[] | select(.focused == true) | "\(.x),\(.y) \(.width)x\(.height)"')
    #     date=$(date +"%Y-%m-%d-%H-%M-%S")
    # if ! ${getExe wf-recorder} -g "$output" -a -f "$HOME/Videos/recorded/$date.mp4"; then
    "SUPER, F1"."SUPER, F1".script = ''
      mkdir -p "$HOME/Videos/recorded"
      echo 1 > /tmp/recording-value
      if ! ${getExe gpu-screen-recorder} -w screen -f 60 -c mp4 -r 450 -o "$HOME/Videos/recorded"; then
        notify-send "Screen recording failed"
        echo 0 > /tmp/recording-value
        exit 1
      fi
    '';

    # ${getExe killall} wf-recorder
    "SUPER, F2".script = ''
      ${getExe killall} -SIGUSR1 gpu-screen-recorder
      notify-send "screen recording saved"
    '';

    # ${getExe killall} wf-recorder
    "SUPER, F3".script = ''
      ${getExe killall} -SIGINT gpu-screen-recorder
      echo 0 > /tmp/recording-value
      notify-send "screen recording stopped"
    '';
  };
}

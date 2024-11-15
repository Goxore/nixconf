{
  pkgs,
  lib,
  inputs,
  ...
}: {
  options = {
    myHomeManager.keybinds = lib.mkOption {
      default = {
        "$mainMod, A" = {
          "f"."f" = {
            exec = "firefox";
          };
        };

        "$mainMod, B" = {
          "f"."f" = {
            exec = "pcmanfm";
          };
        };
      };
    };
  };

  config = let
    inherit (lib) getExe;
  in {
    myHomeManager.keybinds = {
      "SUPER, d" = {
        "f".package = pkgs.firefox;
        "t".package = pkgs.telegram-desktop;
        "s".package = pkgs.pavucontrol;
        "b".package = pkgs.rofi-bluetooth;
        "h".script = ''
          ${getExe pkgs.kitty} -e ${getExe pkgs.btop}
        '';
        "c".script = ''
          ${getExe pkgs.kitty} -e ${getExe pkgs.libqalculate}
        '';
      };

      "SUPER, p".script = ''
        ${getExe pkgs.playerctl} play-pause'';

      "SUPERCONTROL, S".script = ''
        ${getExe pkgs.grim} -l 0 - | ${pkgs.wl-clipboard}/bin/wl-copy'';

      "SUPERSHIFT, E".script = ''
        ${pkgs.wl-clipboard}/bin/wl-paste | ${getExe pkgs.swappy} -f -
      '';

      "SUPERSHIFT, S".script = ''
        ${getExe pkgs.grim} -g "$(${getExe pkgs.slurp} -w 0)" - \
        | ${pkgs.wl-clipboard}/bin/wl-copy
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
        if ! ${getExe pkgs.gpu-screen-recorder} -w screen -f 60 -c mp4 -r 450 -o "$HOME/Videos/recorded"; then
          notify-send "Screen recording failed"
          echo 0 > /tmp/recording-value
          exit 1
        fi
      '';

      "SUPER, F2".script = ''
        ${getExe pkgs.killall} -SIGUSR1 gpu-screen-recorder
        notify-send "screen recording saved"
      '';

      "SUPER, F3".script = ''
        ${getExe pkgs.killall} -SIGINT gpu-screen-recorder
        echo 0 > /tmp/recording-value
        notify-send "screen recording stopped"
      '';
    };
  };
}

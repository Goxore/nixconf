{
  pkgs,
  config,
  inputs,
  myLib,
  lib,
  ...
}: let
  cfg = config;

  # CUSTOMZSHTOSOURCE is a work-around to source files in the same zsh instance
  # zsh -c exits after `source`
  shell = script: ["${pkgs.writeShellScriptBin "script" script}/bin/script"];
  makeScratchPad = {
    name,
    script,
    terminal ? true,
  }: let
    command =
      if terminal
      then ''"CUSTOMZSHTOSOURCE=\"${pkgs.writeText "text" script}\" alacritty -e 'zsh'"''
      else ''${script}'';
  in
    shell ''
      hyprctl workspaces | grep ${name}-scratchpad || hyprctl dispatch exec \[workspace special:${name}-scratchpad\] ${command}
      hyprctl dispatch togglespecialworkspace ${name}-scratchpad
    '';
in {
  # xremap's flake does not have "enable" option, so I'm adding it myself
  imports = [
    (myLib.extendModule {
      # grabbing the first import from xremap's home-manager module
      path = builtins.head inputs.xremap-flake.homeManagerModules.default.imports;

      # adding option
      extraOptions = {
        services.xremap.enable = lib.mkEnableOption "enable xremap";
      };

      # only enabling xremap if this option is toggles
      configExtension = config: lib.mkIf cfg.services.xremap.enable config;
    })
  ];

  services.xremap = {
    enable = true;
    withHypr = true;
    config = {
      keymap = [
        {
          mode = "default";
          name = "general keybindings";
          remap = {
            super-p = {
              launch = shell "${pkgs.playerctl}/bin/playerctl play-pause";
            };
            # "super-]" = {
            #   launch = shell "${pkgs.playerctl}/bin/playerctl next";
            # };
            # "super-[" = {
            #   launch = shell "${pkgs.playerctl}/bin/playerctl previous";
            # };
            super-CONTROL-S = {
              launch = shell "${pkgs.grim}/bin/grim -l 0 - | ${pkgs.wl-clipboard}/bin/wl-copy";
            };
            super-SHIFT-E = {
              launch =
                shell "${pkgs.wl-clipboard}/bin/wl-paste | ${pkgs.swappy}/bin/swappy -f -";
            };
            super-SHIFT-S = {
              launch =
                shell
                ''
                  ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - \
                  | ${pkgs.imagemagick}/bin/convert - -shave 1x1 PNG:- \
                  | ${pkgs.wl-clipboard}/bin/wl-copy
                '';
            };
            # SUPER + DO actions
            super-d = {
              remap = {
                b = {
                  launch = shell "${pkgs.rofi-bluetooth}/bin/rofi-bluetooth";
                };
                p = {
                  launch = makeScratchPad {
                    name = "rbw";
                    script = ''
                      rbw unlock

                      export type() {
                          rbw unlock || exit
                          password="$(rbw get "$@")"

                          if [[ -z "$password" ]]; then
                            return
                          fi

                          hyprctl dispatch togglespecialworkspace rbw-scratchpad
                          sleep 1
                          ${pkgs.wtype}/bin/wtype "$password"
                      }

                      export typefzf() {
                          password="$(echo "$(rbw list --fields name,user | fzf)" | xargs rbw get)"

                          if [[ -z "$password" ]]; then
                            return
                          fi

                          hyprctl dispatch togglespecialworkspace rbw-scratchpad
                          sleep 1
                          ${pkgs.wtype}/bin/wtype "$password"
                      }
                    '';
                  };
                };
                c = {
                  launch = makeScratchPad {
                    name = "calculator";
                    script = ''
                      ${pkgs.libqalculate}/bin/qalc
                    '';
                  };
                };
                h = {
                  launch = makeScratchPad {
                    name = "top";
                    script = ''
                      ${pkgs.bottom}/bin/btm
                      exit
                    '';
                  };
                };
                f = {launch = ["firefox"];};
                s = {
                  launch = makeScratchPad {
                    name = "pavucontrol";
                    script = "${pkgs.pavucontrol}/bin/pavucontrol";
                    terminal = false;
                  };
                };
                t = {launch = ["telegram-desktop"];};
              };
            };
            super-u = {set_mode = "alternative";};
            super-v = {
              launch =
                shell
                ''
                  # toggles microphone on/off
                  amixer sset Capture toggle && amixer get Capture | grep "\[off\]" \
                      && (notify-send "MIC switched OFF") \
                      || (notify-send "MIC switched ON")
                '';
            };
          };
        }
        # Just for a test
        {
          mode = "alternative";
          name = "alternative keybindings";
          remap = {
            super-i = {launch = ["notify-send" "IT IS MODE2"];};
            super-u = {set_mode = "default";};
          };
        }
      ];
      modmap = [
        {
          name = "main remaps";
          remap = {CapsLock = "esc";};
        }
        # {
        #   application = { only = [ "org.wezfurlong.wezterm" "Alacritty" ]; };
        #   name = "firefox";
        #   remap = {
        #     CapsLock = {
        #       alone = "esc";
        #       alone_timeout_millis = 150;
        #       held = "leftctrl";
        #     };
        #   };
        # }
      ];
    };
  };
}

{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./monitors.nix
    ./keymaps.nix
    ./start.nix
  ];

  options.myHomeManager.hyprland = {
    split-workspaces.enable = lib.mkEnableOption "enable split workspaces plugin";

    windowanimation = lib.mkOption {
      default = "workspaces, 1, 3, myBezier, fade";
      description = ''
        animation for switching workspaces.
        I don't like having slide on my ultrawide monitor
      '';
    };
  };

  config = {
    myHomeManager.waybar.enable = lib.mkDefault false;
    # myHomeManager.ags.enable = lib.mkDefault true;
    # myHomeManager.astalshell.enable = lib.mkDefault true;
    myHomeManager.quickshell.enable = lib.mkDefault true;
    myHomeManager.hyprland.split-workspaces.enable = lib.mkDefault true;
    myHomeManager.keymap.enable = lib.mkDefault true;
    myHomeManager.start.enable = lib.mkDefault true;

    wayland.windowManager.hyprland = {
      plugins =
        []
        ++ lib.optional
        config.myHomeManager.hyprland.split-workspaces.enable
        (pkgs.callPackage ./split-workspaces.nix {});

      enable = true;
      settings = {
        workspace = [
          "w[t1], gapsout:0, gapsin:0"
          "w[tg1], gapsout:0, gapsin:0"
          "f[1], gapsout:0, gapsin:0"
        ];

        windowrulev2 = [
          "bordersize 0, floating:0, onworkspace:w[t1]"
          "rounding 0, floating:0, onworkspace:w[t1]"
          "bordersize 0, floating:0, onworkspace:w[tg1]"
          "rounding 0, floating:0, onworkspace:w[tg1]"
          "bordersize 0, floating:0, onworkspace:f[1]"
          "rounding 0, floating:0, onworkspace:f[1]"
        ];

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          "col.active_border" = lib.mkForce "rgba(${config.stylix.base16Scheme.base0E}ff) rgba(${config.stylix.base16Scheme.base09}ff) 60deg";
          "col.inactive_border" = lib.mkForce "rgba(${config.stylix.base16Scheme.base00}ff)";

          layout = "dwindle";
        };

        monitor =
          lib.mapAttrsToList
          (
            name: m: let
              resolution = "${toString m.width}x${toString m.height}@${toString m.refreshRate}";
              position = "${toString m.x}x${toString m.y}";
            in "${name},${
              if m.enabled
              then "${resolution},${position},1"
              else "disable"
            }"
          )
          (config.myHomeManager.monitors);

        env = [
          "XCURSOR_SIZE,24"
        ];

        input = {
          kb_layout = "us,ru,ua";
          kb_variant = "";
          kb_model = "";
          kb_options = "grp:alt_shift_toggle,caps:escape";

          kb_rules = "";

          follow_mouse = 1;

          touchpad = {
            natural_scroll = false;
          };

          repeat_rate = 40;
          repeat_delay = 250;
          force_no_accel = true;

          sensitivity = 0.0; # -1.0 - 1.0, 0 means no modification.
        };

        misc = {
          enable_swallow = true;
          force_default_wallpaper = 0;

          # swallow_regex = "^(Alacritty|wezterm)$";
        };

        binds = {
          movefocus_cycles_fullscreen = 0;
        };

        debug = {
          suppress_errors = true;
        };

        decoration = {
          rounding = 12;
          rounding_power = 7;

          shadow = {
            enabled = true;
            shadow_range = 30;
          };
        };

        animations = {
          enabled = true;

          # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

          bezier = "myBezier, 0.25, 0.9, 0.1, 1.02";

          animation =
            [
              "windows, 1, 7, myBezier"
              "windowsOut, 1, 7, default, popin 80%"
              "border, 1, 10, default"
              "borderangle, 1, 8, default"
              "fade, 1, 7, default"
            ]
            ++ [config.myHomeManager.hyprland.windowanimation];
        };

        dwindle = {
          # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
          pseudotile = true;
          preserve_split = true;
          # no_gaps_when_only = true;
          force_split = 2;
        };

        master = {
          # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
          # new_is_master = true;
          # orientation = "center";
        };

        gestures = {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          workspace_swipe = false;
        };
      };
    };

    home.packages = with pkgs; [
      grim
      slurp
      wl-clipboard

      swww

      networkmanagerapplet

      rofi-wayland
    ];
  };
}

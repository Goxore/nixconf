{self, ...}: {
  flake.nixosModules.hyprland = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit
      (lib)
      getExe
      mapAttrsToList
      mkForce
      ;

    mod = "SUPER";
    terminal = self.packages.${pkgs.system}.terminal;
  in {
    programs.hyprland.enable = true;

    home.programs.hyprland.enable = true;
    home.programs.hyprland.settings = {
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
        "col.active_border" = mkForce "rgba(${self.themeNoHash.base0E}ff) rgba(${self.themeNoHash.base09}ff) 60deg";
        "col.inactive_border" = mkForce "rgba(${self.themeNoHash.base00}ff)";

        layout = "dwindle";
      };

      monitor =
        mapAttrsToList
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
        (config.preferences.monitors);

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

        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 3, myBezier, fade"
        ];
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

      bind = let
        toWSNumber = n: (toString (
          if n == 0
          then 10
          else n
        ));

        moveworkspaces = map (n: "${mod} SHIFT, ${toString n}, movetoworkspace, ${toWSNumber n}") [1 2 3 4 5 6 7 8 9 0];
        woworkspaces = map (n: "${mod}, ${toString n}, workspace, ${toWSNumber n}") [1 2 3 4 5 6 7 8 9 0];
      in
        [
          "${mod}, return, exec, ${getExe terminal}"
          "${mod}, Q, killactive,"
          "${mod} SHIFT, F, togglefloating,"
          "${mod}, F, fullscreen,"
          "${mod}, T, pin,"
          "${mod}, G, togglegroup,"
          "${mod}, bracketleft, changegroupactive, b"
          "${mod}, bracketright, changegroupactive, f"
          # "${mod}, S, exec, ${getExe pkgs.rofi} -show drun -show-icons"
          "${mod}, S, exec, ${getExe self.packages.${pkgs.system}.noctalia-shell} ipc call launcher toggle"
          "${mod}, P, pin, active"

          ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-"

          "${mod}, left, movefocus, l"
          "${mod}, right, movefocus, r"
          "${mod}, up, movefocus, u"
          "${mod}, down, movefocus, d"

          "${mod}, h, movefocus, l"
          "${mod}, l, movefocus, r"
          "${mod}, k, movefocus, u"
          "${mod}, j, movefocus, d"

          "${mod} SHIFT, h, movewindow, l"
          "${mod} SHIFT, l, movewindow, r"
          "${mod} SHIFT, k, movewindow, u"
          "${mod} SHIFT, j, movewindow, d"
        ]
        ++ woworkspaces
        ++ moveworkspaces;

      binde = [
        "${mod} SHIFT, h, moveactive, -20 0"
        "${mod} SHIFT, l, moveactive, 20 0"
        "${mod} SHIFT, k, moveactive, 0 -20"
        "${mod} SHIFT, j, moveactive, 0 20"

        "${mod} CTRL, l, resizeactive, 30 0"
        "${mod} CTRL, h, resizeactive, -30 0"
        "${mod} CTRL, k, resizeactive, 0 -10"
        "${mod} CTRL, j, resizeactive, 0 10"
      ];

      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "${mod}, mouse:272, movewindow"
        "${mod}, mouse:273, resizewindow"
      ];
    };

    environment.systemPackages = with pkgs; [
      grim
      slurp
      wl-clipboard

      swww

      networkmanagerapplet

      rofi
    ];
  };
}

{
  pkgs,
  config,
  lib,
  inputs,
  osConfig,
  ...
}: let
  moveToMonitor =
    lib.mapAttrsToList
    (
      id: workspace: "hyprctl dispatch moveworkspacetomonitor ${id} ${toString workspace.monitorId}"
    )
    config.myHomeManager.workspaces;

  moveToMonitorScript = pkgs.writeShellScriptBin "script" ''
    ${lib.concatLines moveToMonitor}
  '';

  generalStartScript = pkgs.writeShellScriptBin "start" ''
    ${pkgs.swww}/bin/swww init &

    ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator &

    # hyprctl setcursor Bibata-Modern-Ice 16 &

    systemctl --user import-environment PATH &
    systemctl --user restart xdg-desktop-portal.service &


    # wait a tiny bit for wallpaper
    sleep 2


    ${pkgs.swww}/bin/swww img ${config.stylix.image} &

    # wait for monitors to connect
    sleep 3
    ags &

    ${lib.getExe moveToMonitorScript}

    # general startupScript extension
    ${config.myHomeManager.startupScript}
  '';

  autostarts =
    lib.lists.flatten
    (lib.mapAttrsToList
      (
        id: workspace: (map (startentry: "[workspace ${id} silent] ${startentry}") workspace.autostart)
      )
      config.myHomeManager.workspaces);

  monitorScript = pkgs.writeShellScriptBin "script" ''
    handle() {
      case $1 in monitoradded*)
        ${lib.getExe moveToMonitorScript}
      esac
    }

    ${lib.getExe pkgs.socat} - "UNIX-CONNECT:/tmp/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock" | while read -r line; do handle "$line"; done
  '';
  exec-once =
    [
      (lib.getExe generalStartScript)
      (lib.getExe monitorScript)

      # I forgor why i need this
      "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    ]
    ++ autostarts;
in {
  imports = [
    ./monitors.nix
  ];

  options = {
    hyprlandExtra = lib.mkOption {
      default = "";
      description = ''
        extra hyprland config lines
      '';
    };
  };

  config = {
    myHomeManager.waybar.enable = lib.mkDefault true;
    myHomeManager.ags.enable = lib.mkDefault true;

    wayland.windowManager.hyprland = {
      # package = inputs.hyprland.packages."${pkgs.system}".hyprland;
      enable = true;
      # enableNvidiaPatches = true;
      settings = {
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

        # workspace =
        #   lib.mapAttrsToList
        #   (
        #     name: m: "${m.name},${m.workspace}"
        #   )
        #   (lib.filter (m: m.enabled && m.workspace != null) config.myHomeManager.monitors);

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

        decoration = {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more

          rounding = 5;

          drop_shadow = true;
          shadow_range = 30;
          shadow_render_power = 3;
          # "col.shadow" = "rgba(1a1a1aee)";
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
            # "workspaces, 1, 3, default, slidevert"
            # "workspaces, 1, 3, myBezier, slidefadevert"
            "workspaces, 1, 3, myBezier, fade"
          ];
        };

        dwindle = {
          # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
          pseudotile = true; # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
          preserve_split = true; # you probably want this
        };

        master = {
          # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
          new_is_master = true;
          # soon :)
          # orientation = "center";
        };

        gestures = {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          workspace_swipe = false;
        };

        # Example per-device config
        # See https://wiki.hyprland.org/Configuring/Keywords/#executing for more

        # Example windowrule v1
        # windowrule = float, ^(kitty)$
        # Example windowrule v2
        # windowrulev2 = float,class:^(kitty)$,title:^(kitty)$
        # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more

        # See https://wiki.hyprland.org/Configuring/Keywords/ for more
        "$mainMod" =
          if (osConfig.sharedSettings.altIsSuper or false)
          then "ALT"
          else "SUPER";

        # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
        bind =
          [
            "$mainMod, return, exec, kitty"
            "$mainMod, Q, killactive,"
            "$mainMod SHIFT, M, exit,"
            "$mainMod SHIFT, F, togglefloating,"
            "$mainMod, F, fullscreen,"
            "$mainMod, G, togglegroup,"
            "$mainMod, bracketleft, changegroupactive, b"
            "$mainMod, bracketright, changegroupactive, f"
            "$mainMod, S, exec, rofi -show drun -show-icons"
            "$mainMod, P, pin, active"

            "$mainMod, left, movefocus, l"
            "$mainMod, right, movefocus, r"
            "$mainMod, up, movefocus, u"
            "$mainMod, down, movefocus, d"

            "$mainMod, h, movefocus, l"
            "$mainMod, l, movefocus, r"
            "$mainMod, k, movefocus, u"
            "$mainMod, j, movefocus, d"

            "$mainMod SHIFT, h, movewindow, l"
            "$mainMod SHIFT, l, movewindow, r"
            "$mainMod SHIFT, k, movewindow, u"
            "$mainMod SHIFT, j, movewindow, d"
          ]
          ++ map (n: "$mainMod SHIFT, ${toString n}, movetoworkspace, ${toString (
            if n == 0
            then 10
            else n
          )}") [1 2 3 4 5 6 7 8 9 0]
          ++ map (n: "$mainMod, ${toString n}, workspace, ${toString (
            if n == 0
            then 10
            else n
          )}") [1 2 3 4 5 6 7 8 9 0];

        binde = [
          "$mainMod SHIFT, h, moveactive, -20 0"
          "$mainMod SHIFT, l, moveactive, 20 0"
          "$mainMod SHIFT, k, moveactive, 0 -20"
          "$mainMod SHIFT, j, moveactive, 0 20"

          "$mainMod CTRL, l, resizeactive, 30 0"
          "$mainMod CTRL, h, resizeactive, -30 0"
          "$mainMod CTRL, k, resizeactive, 0 -10"
          "$mainMod CTRL, j, resizeactive, 0 10"
        ];

        bindm = [
          # Move/resize windows with mainMod + LMB/RMB and dragging
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        # league of legends fixes
        windowrulev2 = [
          "float,class:^(leagueclientux.exe)$,title:^(League of Legends)$"
          "tile,class:^(league of legends.exe)$,title:^(League of Legends (TM) Client)$ windowrule = size 1920 1080,^(league of legends.exe)$"
        ];

        windowrule = [
          "size 1600 900,^(leagueclientux.exe)$"
          "center,^(leagueclientux.exe)$"
          "center,^(league of legends.exe)$"
          "forceinput,^(league of legends.exe)$"
        ];

        exec-once = exec-once;
      };
    };

    home.packages = with pkgs; [
      grim
      slurp
      wl-clipboard

      eww
      swww

      networkmanagerapplet

      rofi-wayland

      (pkgs.waybar.overrideAttrs (oldAttrs: {
        mesonFlags = oldAttrs.mesonFlags ++ ["-Dexperimental=true"];
      }))
    ];
  };
}

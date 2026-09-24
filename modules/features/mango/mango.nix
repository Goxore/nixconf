{
  wrapperModules,
  self,
  lib,
  ...
}: {
  wrappers.mangowc = {
    wlib,
    pkgs,
    config,
    ...
  }: let
    exeOf = self.lib.dynamicExe config.dynamicMode;

    vjshellExe = exeOf pkgs.vj.vjshell;
    vjprojExe = exeOf pkgs.vj.vjproj;

    resolve = self.lib.keymap.resolve {
      inherit pkgs;
      vjshell = vjshellExe;
    };

    mod = "SUPER";

    mmsgExe =
      if config.dynamicMode
      then "/run/current-system/sw/bin/mmsg"
      else "${pkgs.mangowc}/bin/mmsg";

    projectTerminal = pkgs.writeShellScript "vjproj-terminal" ''
      cd "$(${vjprojExe} dir)" 2>/dev/null || cd "$HOME"
      exec ${config.terminal} "$@"
    '';

    wsKeys =
      lib.zipListsWith (key: ws: {inherit key ws;})
      ["1" "2" "3" "4" "5" "6" "8" "9" "0"]
      (lib.range 1 9);
    sessionVars = lib.concatStringsSep " " (
      ["WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP" "MANGO_INSTANCE_SIGNATURE"]
      ++ lib.optional config.dynamicMode "NIXCONF_ROOT"
    );
    wsFor = key: (lib.findFirst (e: e.key == key) null wsKeys).ws;
  in {
    imports = [wlib.wrapperModules.mangowc wrapperModules._dynamic];

    options.terminal = lib.mkOption {
      type = lib.types.str;
      default = exeOf pkgs.vj.terminal;
    };

    config = {
      package = pkgs.mangowc.overrideAttrs (previous: {
        postPatch =
          (previous.postPatch or "")
          + ''
            substituteInPlace src/main.c \
              --replace-fail 'wlr_primary_selection_v1_device_manager_create(server.display);' ""
          '';
      });

      env = {
        XCURSOR_THEME = self.lib.cursor.name;
        XCURSOR_SIZE = toString self.lib.cursor.size;
      };

      autostart_sh = ''
        if [ "$XDG_RUNTIME_DIR" = "/run/user/$(${pkgs.coreutils}/bin/id -u)" ]; then
          ${pkgs.systemd}/bin/systemctl --user import-environment ${sessionVars}
          ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd ${sessionVars}
          ${pkgs.systemd}/bin/systemctl --user start nixos-fake-graphical-session.target
          ${pkgs.systemd}/bin/systemctl --user restart vjproj-serve.service
          ${
          if config.dynamicMode
          then "${pkgs.systemd}/bin/systemctl --user restart vjshell.service"
          else "${vjshellExe} &"
        }
        else
          ${vjshellExe} &
        fi

        ${pkgs.swaybg}/bin/swaybg -i ${self.lib.wallpaper} -m fill &
      '';

      settings = {
        blur = 0;
        blur_layer = 0;
        blur_optimized = 1;
        blur_params_num_passes = 2;
        blur_params_radius = 5;
        blur_params_noise = 0.02;
        blur_params_brightness = 0.9;
        blur_params_contrast = 0.9;
        blur_params_saturation = 1.2;

        shadows = 0;
        layer_shadows = 0;
        shadow_only_floating = 1;
        shadows_size = 10;
        shadows_blur = 15;
        shadows_position_x = 0;
        shadows_position_y = 0;
        shadowscolor = "0x000000ff";

        border_radius = 9;
        no_radius_when_single = 0;
        focused_opacity = 1.0;
        unfocused_opacity = 1.0;

        animations = 1;
        layer_animations = 1;
        animation_type_open = "slide";
        animation_type_close = "slide";
        animation_fade_in = 1;
        animation_fade_out = 1;
        tag_animation_direction = 1;
        zoom_initial_ratio = 0.4;
        zoom_end_ratio = 0.8;
        fadein_begin_opacity = 0.5;
        fadeout_begin_opacity = 0.8;
        animation_duration_move = 500;
        animation_duration_open = 400;
        animation_duration_tag = 350;
        animation_duration_close = 800;
        animation_duration_focus = 0;

        animation_curve_open = "0.46,1.0,0.29,1";
        animation_curve_move = "0.46,1.0,0.29,1";
        animation_curve_tag = "0.46,1.0,0.29,1";
        animation_curve_close = "0.08,0.92,0,1";
        animation_curve_focus = "0.46,1.0,0.29,1";
        animation_curve_opafadeout = "0.5,0.5,0.5,0.5";
        animation_curve_opafadein = "0.46,1.0,0.29,1";

        scroller_structs = 20;
        scroller_default_proportion = 0.8;
        scroller_focus_center = 0;
        scroller_prefer_center = 0;
        edge_scroller_pointer_focus = 1;
        scroller_default_proportion_single = 1.0;
        scroller_proportion_preset = "0.5,0.8,1.0";

        new_is_master = 1;
        default_mfact = 0.55;
        default_nmaster = 1;
        smartgaps = 1;

        hotarea_size = 10;
        enable_hotarea = 0;
        overviewgappi = 5;
        overviewgappo = 30;

        no_border_when_single = 1;
        axis_bind_apply_timeout = 100;
        focus_on_activate = 0;
        idleinhibit_ignore_visible = 0;
        sloppyfocus = 1;
        warpcursor = 1;
        focus_cross_monitor = 0;
        focus_cross_tag = 0;
        enable_floating_snap = 0;
        snap_distance = 30;
        cursor_theme = self.lib.cursor.name;
        cursor_size = self.lib.cursor.size;
        drag_tile_to_tile = 1;

        repeat_rate = 40;
        repeat_delay = 250;
        numlockon = 0;
        xkb_rules_layout = "us,ru,ua";
        xkb_rules_options = "grp:alt_shift_toggle";

        disable_trackpad = 0;
        tap_to_click = 1;
        tap_and_drag = 1;
        drag_lock = 1;
        trackpad_natural_scrolling = 0;
        trackpad_disable_while_typing = 1;
        trackpad_left_handed = 0;
        trackpad_middle_button_emulation = 0;
        swipe_min_threshold = 1;

        mouse_natural_scrolling = 0;
        mouse_accel_profile = 1;
        mouse_accel_speed = 0.0;
        mouse_left_handed = 0;
        mouse_middle_button_emulation = 0;

        gappih = 5;
        gappiv = 5;
        gappoh = 10;
        gappov = 10;
        scratchpad_width_ratio = 0.8;
        scratchpad_height_ratio = 0.9;
        borderpx = 2;

        rootcolor = "0x${self.lib.themeNoHash.base00}ff";
        bordercolor = "0x${self.lib.themeNoHash.base00}ff";
        focuscolor = "0x${self.lib.themeNoHash.base0E}ff";
        maximizescreencolor = "0x${self.lib.themeNoHash.base0B}ff";
        urgentcolor = "0x${self.lib.themeNoHash.base08}ff";
        scratchpadcolor = "0x${self.lib.themeNoHash.base0A}ff";
        globalcolor = "0x${self.lib.themeNoHash.base0E}ff";
        overlaycolor = "0x${self.lib.themeNoHash.base0C}ff";

        tag_num = 17;

        tagrule = map (id: "id:${toString id},layout_name:tile") (lib.range 1 17);

        windowrule = [
          "istaganchor:1,appid:kitty"

          "force_render:1,appid:firefox,title:^Picture-in-Picture$"
          "force_render:1,appid:chromium,title:^Picture in picture$"
        ];

        layerrule = [
          "animation_type_open:zoom,layer_name:vjshell-launcher"
          "animation_type_close:zoom,layer_name:vjshell-launcher"
        ];

        bind = let
          viewBinds = map (e: "${mod},${e.key},spawn,${vjprojExe} view ${toString e.ws}") wsKeys;
          tagBinds = map (e: "${mod}+SHIFT,${e.key},spawn,${vjprojExe} tag ${toString e.ws}") wsKeys;
          switchBinds = map (n: "${mod}+CTRL,${toString n},spawn,${vjprojExe} switch --position ${toString n}") (lib.range 1 9);
          sendBinds = map (n: "${mod}+CTRL+SHIFT,${toString n},spawn,${vjprojExe} send --position ${toString n}") (lib.range 1 9);

          declaredBinds =
            lib.mapAttrsToList
            (chord: e: "${chord},spawn,${resolve e.cmd}")
            self.keymap.binds;
        in
          viewBinds
          ++ tagBinds
          ++ switchBinds
          ++ sendBinds
          ++ declaredBinds
          ++ [
            "${mod},space,spawn,${vjshellExe} ipc call launcher toggle"
            "${mod},Return,spawn,${projectTerminal}"

            "${mod},m,quit"
            "${mod},q,killclient"

            "${mod},h,focusdir,left"
            "${mod},l,focusdir,right"
            "${mod},k,focusdir,up"
            "${mod},j,focusdir,down"

            "${mod},Left,focusdir,left"
            "${mod},Right,focusdir,right"
            "${mod},Up,focusdir,up"
            "${mod},Down,focusdir,down"

            "${mod}+SHIFT,Up,exchange_client,up"
            "${mod}+SHIFT,Down,exchange_client,down"
            "${mod}+SHIFT,Left,exchange_client,left"
            "${mod}+SHIFT,Right,exchange_client,right"
            "${mod}+SHIFT,k,exchange_client,up"
            "${mod}+SHIFT,j,exchange_client,down"
            "${mod}+SHIFT,h,exchange_client,left"
            "${mod}+SHIFT,l,exchange_client,right"

            "${mod}+CTRL,h,resizewin,-50,+0"
            "${mod}+CTRL,l,resizewin,+50,+0"
            "${mod}+CTRL,k,resizewin,+0,-50"
            "${mod}+CTRL,j,resizewin,+0,+50"

            "${mod}+CTRL,Left,resizewin,-50,+0"
            "${mod}+CTRL,Right,resizewin,+50,+0"
            "${mod}+CTRL,Up,resizewin,+0,-50"
            "${mod}+CTRL,Down,resizewin,+0,+50"

            "${mod},t,toggleglobal"
            "ALT,Tab,overcircle,next"
            "${mod},f,togglemaximizescreen"
            "${mod}+shift,f,togglefloating"
            "${mod},g,togglefullscreen"
            "SUPER,i,minimized"
            "SUPER,o,toggleoverlay"
            "SUPER+SHIFT,I,restore_minimized"
            "ALT,z,toggle_scratchpad"

            "ALT,e,set_proportion,1.0"
            "ALT,x,switch_proportion_preset"

            "SUPER,n,switch_layout"

            "CTRL,Left,spawn,${vjprojExe} left --occupied"
            "CTRL,Right,spawn,${vjprojExe} right --occupied"

            "${mod}+CTRL,S,spawn,${exeOf pkgs.vj.screenshot}"
            "${mod}+SHIFT,S,spawn,${exeOf pkgs.vj.screenshotRegion}"
            "${mod}+SHIFT,E,spawn,${exeOf pkgs.vj.pipeSwappy}"

            "${mod},S,spawn,${vjshellExe} ipc call launcher toggle"

            "${mod},y,spawn,${vjshellExe} ipc call musicLyricsService toggle"

            "${mod},d,spawn,${vjshellExe} ipc call menu toggle"

            "${mod},Tab,spawn,${vjprojExe} next"
            "${mod},e,spawn,${vjprojExe} fresh"
            "${mod},a,spawn,${vjshellExe} ipc call projects toggle"
            "${mod}+SHIFT,a,spawn,${vjshellExe} ipc call projects edit"
            "${mod}+SHIFT,r,spawn,${mmsgExe} dispatch reload_config"
            "${mod}+SHIFT,F1,spawn,${vjprojExe} reset"
          ];

        mousebind = let
          declaredMouse =
            lib.mapAttrsToList
            (chord: e: "${chord},spawn,${resolve e.cmd}")
            self.keymap.mouse;
        in
          declaredMouse
          ++ [
            "SUPER,btn_left,moveresize,curmove"
            "SUPER,btn_right,moveresize,curresize"

            "SUPER,btn_side,spawn,${vjprojExe} view ${toString (wsFor "9")}"
            "SUPER,btn_back,spawn,${vjprojExe} view ${toString (wsFor "9")}"
            "SUPER,btn_extra,spawn,${vjprojExe} view ${toString (wsFor "0")}"
            "SUPER,btn_forward,spawn,${vjprojExe} view ${toString (wsFor "0")}"
          ];

        axisbind = [
          "SUPER,UP,spawn,${exeOf pkgs.vj.volYtMusic} up"
          "SUPER,DOWN,spawn,${exeOf pkgs.vj.volYtMusic} down"

          "SUPER+CTRL,UP,spawn,${exeOf pkgs.vj.vol} up"
          "SUPER+CTRL,DOWN,spawn,${exeOf pkgs.vj.vol} down"
        ];
      };
    };
  };

  wrappers.mangowcDynamic = {...}: {
    imports = [wrapperModules.mangowc];
    dynamicMode = true;
    flags."-c" = lib.mkForce "/etc/mango/config.conf";
  };
}

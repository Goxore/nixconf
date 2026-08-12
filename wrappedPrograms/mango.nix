{
  self,
  lib,
  ...
}: {
  flake.wrappers.mangowc = {
    wlib,
    pkgs,
    config,
    ...
  }: let
    vjshellExe = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.vjshell;
    vjprojExe = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.vjproj;

    mod = "SUPER";
    wsKeys = [
      {key = "1"; ws = 1;}
      {key = "2"; ws = 2;}
      {key = "3"; ws = 3;}
      {key = "4"; ws = 4;}
      {key = "5"; ws = 5;}
      {key = "6"; ws = 6;}
      {key = "8"; ws = 7;}
      {key = "9"; ws = 8;}
      {key = "0"; ws = 9;}
    ];
    wsFor = key: (lib.findFirst (e: e.key == key) null wsKeys).ws;
  in {
    imports = [wlib.wrapperModules.mangowc];

    options.terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
    };

    config = {
      package = pkgs.mangowc;

      env = {
        XCURSOR_THEME = self.cursor.name;
        XCURSOR_SIZE = toString self.cursor.size;
      };

      autostart_sh = ''
        ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
        ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
        ${pkgs.systemd}/bin/systemctl --user start nixos-fake-graphical-session.target

        ${vjshellExe} &
        ${pkgs.swaybg}/bin/swaybg -i ${self.wallpaper} -m fill &
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
        ov_tab_mode = 1;
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
        cursor_theme = self.cursor.name;
        cursor_size = self.cursor.size;
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
        disable_while_typing = 1;
        left_handed = 0;
        middle_button_emulation = 0;
        swipe_min_threshold = 1;

        mouse_natural_scrolling = 0;
        mouse_accel_profile = 1;
        mouse_accel_speed = 0.0;

        gappih = 5;
        gappiv = 5;
        gappoh = 10;
        gappov = 10;
        scratchpad_width_ratio = 0.8;
        scratchpad_height_ratio = 0.9;
        borderpx = 2;

        rootcolor = "0x${self.themeNoHash.base00}ff";
        bordercolor = "0x${self.themeNoHash.base00}ff";
        focuscolor = "0x${self.themeNoHash.base0E}ff";
        maximizescreencolor = "0x${self.themeNoHash.base0B}ff";
        urgentcolor = "0x${self.themeNoHash.base08}ff";
        scratchpadcolor = "0x${self.themeNoHash.base0A}ff";
        globalcolor = "0x${self.themeNoHash.base0E}ff";
        overlaycolor = "0x${self.themeNoHash.base0C}ff";

        tag_num = 25;

        tagrule = map (id: "id:${toString id},layout_name:tile") (lib.range 1 25);

        layerrule = [
          "animation_type_open:zoom,layer_name:vjshell-launcher"
          "animation_type_close:zoom,layer_name:vjshell-launcher"
        ];

        bind = let
          viewBinds = map (e: "${mod},${e.key},spawn,${vjprojExe} view ${toString e.ws}") wsKeys;
          tagBinds = map (e: "${mod}+SHIFT,${e.key},spawn,${vjprojExe} tag ${toString e.ws}") wsKeys;
          switchBinds = map (n: "${mod}+CTRL,${toString n},spawn,${vjprojExe} switch ${toString n}") (lib.range 1 5);
        in
          viewBinds
          ++ tagBinds
          ++ switchBinds
          ++ [
          "${mod},space,spawn,${vjshellExe} ipc call launcher toggle"
          "${mod},Return,spawn,${config.terminal}"

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
          "ALT,Tab,toggleoverview"
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

          "SUPER,Left,spawn,${vjprojExe} left"
          "CTRL,Left,spawn,${vjprojExe} left --occupied"
          "SUPER,Right,spawn,${vjprojExe} right"
          "CTRL,Right,spawn,${vjprojExe} right --occupied"
          "CTRL+SUPER,Left,spawn,${vjprojExe} move-left"
          "CTRL+SUPER,Right,spawn,${vjprojExe} move-right"

          "${mod}+CTRL,S,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.screenshot}"
          "${mod}+SHIFT,S,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.screenshotFull}"
          "${mod}+SHIFT,E,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.pipeSwappy}"

          "${mod},V,spawn,${config.pkgs.alsa-utils}/bin/amixer sset Capture toggle"

          "${mod},S,spawn,${vjshellExe} ipc call launcher toggle"

          "${mod},y,spawn,${vjshellExe} ipc call musicLyricsService toggle"

          "${mod},d,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.menu1}"

          "${mod},Tab,spawn,${vjprojExe} next"
          "${mod}+SHIFT,F1,spawn,${vjprojExe} reset"
        ];

        mousebind = [
          "SUPER,btn_left,moveresize,curmove"
          "SUPER,btn_right,moveresize,curresize"

          "SUPER,btn_side,spawn,${vjprojExe} view ${toString (wsFor "9")}"
          "SUPER,btn_back,spawn,${vjprojExe} view ${toString (wsFor "9")}"
          "SUPER,btn_extra,spawn,${vjprojExe} view ${toString (wsFor "0")}"
          "SUPER,btn_forward,spawn,${vjprojExe} view ${toString (wsFor "0")}"
        ];

        axisbind = [
          "SUPER,UP,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.volYtMusic} up"
          "SUPER,DOWN,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.volYtMusic} down"

          "SUPER+CTRL,UP,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.vol} up"
          "SUPER+CTRL,DOWN,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.vol} down"
        ];
      };
    };
  };
}

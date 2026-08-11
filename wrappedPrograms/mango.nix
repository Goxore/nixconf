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
  in {
    imports = [wlib.wrapperModules.mangowc];

    options.terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
    };

    config = {
      autostart_sh = ''
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

        border_radius = 6;
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

        no_border_when_single = 0;
        axis_bind_apply_timeout = 100;
        focus_on_activate = 0;
        idleinhibit_ignore_visible = 0;
        sloppyfocus = 1;
        warpcursor = 1;
        focus_cross_monitor = 0;
        focus_cross_tag = 0;
        enable_floating_snap = 0;
        snap_distance = 30;
        cursor_size = 24;
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
        accel_profile = 1;

        gappih = 5;
        gappiv = 5;
        gappoh = 10;
        gappov = 10;
        scratchpad_width_ratio = 0.8;
        scratchpad_height_ratio = 0.9;
        borderpx = 4;

        rootcolor = "0x201b14ff";
        bordercolor = "0x444444ff";
        focuscolor = "0xc9b890ff";
        maximizescreencolor = "0x89aa61ff";
        urgentcolor = "0xad401fff";
        scratchpadcolor = "0x516c93ff";
        globalcolor = "0xb153a7ff";
        overlaycolor = "0x14a57cff";

        tagrule = [
          "id:1,layout_name:tile"
          "id:2,layout_name:tile"
          "id:3,layout_name:tile"
          "id:4,layout_name:tile"
          "id:5,layout_name:tile"
          "id:6,layout_name:tile"
          "id:7,layout_name:tile"
          "id:8,layout_name:tile"
          "id:9,layout_name:tile"
          "id:10,layout_name:tile"
        ];

        layerrule = [
          "animation_type_open:zoom,layer_name:vjshell-launcher"
          "animation_type_close:zoom,layer_name:vjshell-launcher"
        ];

        bind = let
          mod = "SUPER";
        in [
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

          "SUPER,Left,viewtoleft,0"
          "CTRL,Left,viewtoleft_have_client,0"
          "SUPER,Right,viewtoright,0"
          "CTRL,Right,viewtoright_have_client,0"
          "CTRL+SUPER,Left,tagtoleft,0"
          "CTRL+SUPER,Right,tagtoright,0"

          "${mod},1,view,1,0"
          "${mod},2,view,2,0"
          "${mod},3,view,3,0"
          "${mod},4,view,4,0"
          "${mod},5,view,5,0"
          "${mod},6,view,6,0"
          "${mod},8,view,7,0"
          "${mod},9,view,8,0"
          "${mod},0,view,9,0"

          "${mod}+SHIFT,1,tag,1,0"
          "${mod}+SHIFT,2,tag,2,0"
          "${mod}+SHIFT,3,tag,3,0"
          "${mod}+SHIFT,4,tag,4,0"
          "${mod}+SHIFT,5,tag,5,0"
          "${mod}+SHIFT,6,tag,6,0"
          "${mod}+SHIFT,8,tag,7,0"
          "${mod}+SHIFT,9,tag,8,0"
          "${mod}+SHIFT,0,tag,9,0"

          "${mod}+CTRL,S,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.screenshot}"
          "${mod}+SHIFT,S,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.screenshotFull}"
          "${mod}+SHIFT,E,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.pipeSwappy}"

          "${mod},V,spawn,${config.pkgs.alsa-utils}/bin/amixer sset Capture toggle"

          "${mod},S,spawn,${vjshellExe} ipc call launcher toggle"

          "${mod},d,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.menu1}"
        ];

        mousebind = [
          "SUPER,btn_left,moveresize,curmove"
          "SUPER,btn_right,moveresize,curresize"
        ];

        axisbind = [
          "SUPER,UP,viewtoleft_have_client"
          "SUPER,DOWN,viewtoright_have_client"

          "SUPER+CTRL,UP,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.vol} up"
          "SUPER+CTRL,DOWN,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.vol} down"
        ];
      };
    };
  };
}

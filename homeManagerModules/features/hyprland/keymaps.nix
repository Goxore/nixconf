{
  pkgs,
  lib,
  config,
  ...
}: {
  wayland.windowManager.hyprland = {
    settings = {
      "$mainMod" = "SUPER";

      bind = let
        toWSNumber = n: (toString (
          if n == 0
          then 10
          else n
        ));

        moveworkspace-command =
          if config.myHomeManager.hyprland.split-workspaces.enable
          then "split-movetoworkspace"
          else "movetoworkspace";
        moveworkspaces = map (n: "$mainMod SHIFT, ${toString n}, ${moveworkspace-command}, ${toWSNumber n}") [1 2 3 4 5 6 7 8 9 0];

        workspace-command =
          if config.myHomeManager.hyprland.split-workspaces.enable
          then "split-workspace"
          else "workspace";

        woworkspaces = map (n: "$mainMod, ${toString n}, ${workspace-command}, ${toWSNumber n}") [1 2 3 4 5 6 7 8 9 0];
      in
        [
          "$mainMod, return, exec, kitty"
          "$mainMod, Q, killactive,"
          "$mainMod SHIFT, M, exit,"
          "$mainMod SHIFT, F, togglefloating,"
          "$mainMod, F, fullscreen,"
          "$mainMod, T, pin,"
          "$mainMod, G, togglegroup,"
          "$mainMod, bracketleft, changegroupactive, b"
          "$mainMod, bracketright, changegroupactive, f"
          "$mainMod, S, exec, rofi -show drun -show-icons"
          "$mainMod, P, pin, active"

          ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-"

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
        ++ woworkspaces
        ++ moveworkspaces;

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
    };

    # ================================================================ #
    # =                   ./../keymap.nix to hypr                    = #
    # ================================================================ #

    extraConfig = let
      wrapWriteApplication = text:
        lib.getExe (pkgs.writeShellApplication {
          name = "script";
          text = text;
        });

      makeHyprBinds = parentKeyName: keyName: keyOptions: let
        newKeyName =
          if builtins.match ".*,.*" keyName != null
          then keyName
          else "," + keyName;
        submapname =
          parentKeyName
          + (builtins.replaceStrings [" " "," "$"] ["hypr" "submaps" "suck"] newKeyName); # :)
      in
        if builtins.hasAttr "script" keyOptions
        then ''
          bind = ${newKeyName}, exec, ${wrapWriteApplication keyOptions.script}
          bind = ${newKeyName},submap,reset
        ''
        else if builtins.hasAttr "package" keyOptions
        then ''
          bind = ${newKeyName}, exec, ${lib.getExe keyOptions.package}
          bind = ${newKeyName},submap,reset
        ''
        else ''
          bind = ${newKeyName}, submap, ${submapname}

          submap = ${submapname}
          ${lib.concatLines (lib.mapAttrsToList (makeHyprBinds submapname) keyOptions)}
          submap = reset
        '';
    in
      lib.mkAfter
      (lib.concatLines
        (lib.mapAttrsToList
          (makeHyprBinds "root")
          config.myHomeManager.keybinds));
  };
}

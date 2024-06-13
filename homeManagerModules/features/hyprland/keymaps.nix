{
  pkgs,
  lib,
  config,
  ...
}: {
  options = {
    hyprlandExtra = lib.mkOption {
      default = "";
      description = ''
        extra hyprland config lines
      '';
    };
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

  config = {
    wayland.windowManager.hyprland = let
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
    in {
      extraConfig =
        lib.mkAfter
        (lib.concatLines
          (lib.mapAttrsToList
            (makeHyprBinds "root")
            config.myHomeManager.keybinds));
    };
  };
}

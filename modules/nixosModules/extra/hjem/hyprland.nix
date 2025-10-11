{
  lib,
  self,
  ...
}: let
  inherit (self.lib.generators) toHyprconf;
in {
  flake.nixosModules.extra_hjem = {
    lib,
    config,
    pkgs,
    ...
  }: let
    inherit
      (lib)
      mkEnableOption
      mkOption
      mkIf
      concatLines
      mapAttrsToList
      getExe
      mkAfter
      ;
    user = config.preferences.user.name;
    cfg = config.home.programs.hyprland;
  in {
    options.home.programs.hyprland = {
      enable = mkEnableOption "hyprland configuration";

      settings = mkOption {
        default = {};
        description = ''
          hyprland configuration
        '';
      };

      extraConfig = mkOption {
        default = "";
        description = ''
          hyprland configuration string
        '';
      };

      finalConfig = mkOption {
        default = "";
      };
    };

    config = mkIf cfg.enable {
      home.programs.hyprland.finalConfig = (toHyprconf {attrs = cfg.settings;}) + cfg.extraConfig;

      hjem.users.${user} = {
        files.".config/hypr/hyprland.conf".text = cfg.finalConfig;
      };

      home.programs.hyprland.settings.exec-once = builtins.map (entry:
        if (builtins.typeOf entry) == "string"
        then getExe (pkgs.writeShellScriptBin "autostart" entry)
        else getExe entry)
      config.preferences.autostart;

      home.programs.hyprland.extraConfig = let
        wrapWriteApplication = text:
          getExe (pkgs.writeShellApplication {
            name = "script";
            text = text;
          });

        # Turns sane looking keymaps into ugly hyprland syntax ones
        # "A" into ",A"
        # "super + d" into "super, d"
        sanitizeKeyName = keyName: let
          replaced = builtins.replaceStrings ["+"] [","] keyName;
        in
          if builtins.match ".*,.*" replaced != null
          then replaced
          else "," + replaced;

        makeHyprBinds = parentKeyName: keyName: keyOptions: let
          finalKeyName = sanitizeKeyName keyName;

          submapname =
            parentKeyName
            + (builtins.replaceStrings [" " "," "$" "+"] ["hypr" "submaps" "syntax" "suck"] finalKeyName);
        in
          if builtins.hasAttr "exec" keyOptions
          then ''
            bind = ${finalKeyName}, exec, ${wrapWriteApplication keyOptions.exec}
            bind = ${finalKeyName},submap,reset
          ''
          else if builtins.hasAttr "package" keyOptions
          then ''
            bind = ${finalKeyName}, exec, ${getExe keyOptions.package}
            bind = ${finalKeyName},submap,reset
          ''
          else ''
            bind = ${finalKeyName}, submap, ${submapname}

            submap = ${submapname}
            ${concatLines (mapAttrsToList (makeHyprBinds submapname) keyOptions)}
            submap = reset
          '';
      in
        mkAfter (
          concatLines (
            mapAttrsToList (makeHyprBinds "root") config.preferences.keymap
          )
        );
    };
  };

  # FULL CREDIT TO
  # https://github.com/nix-community/home-manager/blob/master/modules/services/window-managers/hyprland.nix
  flake.lib.generators.toHyprconf = {
    attrs,
    indentLevel ? 0,
    importantPrefixes ? ["$"],
  }: let
    inherit
      (lib)
      all
      concatMapStringsSep
      concatStrings
      concatStringsSep
      filterAttrs
      foldl
      generators
      hasPrefix
      isAttrs
      isList
      mapAttrsToList
      replicate
      ;

    initialIndent = concatStrings (replicate indentLevel "  ");

    toHyprconf' = indent: attrs: let
      sections = filterAttrs (n: v: isAttrs v || (isList v && all isAttrs v)) attrs;

      mkSection = n: attrs:
        if lib.isList attrs
        then (concatMapStringsSep "\n" (a: mkSection n a) attrs)
        else ''
          ${indent}${n} {
          ${toHyprconf' "  ${indent}" attrs}${indent}}
        '';

      mkFields = generators.toKeyValue {
        listsAsDuplicateKeys = true;
        inherit indent;
      };

      allFields = filterAttrs (n: v: !(isAttrs v || (isList v && all isAttrs v))) attrs;

      isImportantField = n: _:
        foldl (acc: prev:
          if hasPrefix prev n
          then true
          else acc)
        false
        importantPrefixes;

      importantFields = filterAttrs isImportantField allFields;

      fields = builtins.removeAttrs allFields (mapAttrsToList (n: _: n) importantFields);
    in
      mkFields importantFields
      + concatStringsSep "\n" (mapAttrsToList mkSection sections)
      + mkFields fields;
  in
    toHyprconf' initialIndent attrs;
}

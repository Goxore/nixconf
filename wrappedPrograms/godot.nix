{self, ...}: {
  flake.wrappers.godot = {
    wlib,
    pkgs,
    lib,
    ...
  }: let
    inherit (self) theme darken;

    hexColor = alpha: hex: "${builtins.substring 1 6 hex}${alpha}";

    syntaxColors = {
      background_color = hexColor "ff" theme.base00;
      completion_background_color = hexColor "ff" theme.base01;
      completion_selected_color = hexColor "22" theme.base0D;
      completion_existing_color = hexColor "33" theme.base0A;
      completion_scroll_color = hexColor "22" theme.base04;
      completion_font_color = hexColor "ff" theme.base06;
      caret_color = hexColor "ff" theme.base06;
      caret_background_color = hexColor "ff" theme.base00;
      line_number_color = hexColor "ff" theme.base03;
      text_color = hexColor "ff" theme.base06;
      text_selected_color = hexColor "ff" theme.base07;
      keyword_color = hexColor "ff" theme.base0E;
      base_type_color = hexColor "ff" theme.base0A;
      engine_type_color = hexColor "ff" theme.base0D;
      function_color = hexColor "ff" theme.base0D;
      member_variable_color = hexColor "ff" theme.base08;
      comment_color = hexColor "ff" theme.base03;
      string_color = hexColor "ff" theme.base0B;
      number_color = hexColor "ff" theme.base09;
      symbol_color = hexColor "ff" theme.base06;
      selection_color = hexColor "ff" theme.base02;
      brace_mismatch_color = hexColor "ff" theme.base08;
      current_line_color = hexColor "ff" theme.base01;
      line_length_guideline_color = hexColor "ff" theme.base01;
      mark_color = hexColor "38" theme.base08;
      breakpoint_color = hexColor "ff" theme.base08;
      code_folding_color = hexColor "ff" theme.base03;
      word_highlighted_color = hexColor "ff" theme.base02;
      search_result_color = hexColor "ff" (darken 60 theme.base0A);
      search_result_border_color = "ffffff00";
      "gdscript/function_definition_color" = hexColor "ff" theme.base0D;
      "gdscript/node_path_color" = hexColor "ff" theme.base0C;
    };

    syntaxTheme =
      pkgs.writeText "gruvbox.tet"
      ("[color_theme]\n\n"
        + lib.concatStringsSep "\n"
        (lib.mapAttrsToList (name: color: ''${name}="${color}"'') syntaxColors));

    toGdColor = hex: let
      channel = offset: (lib.fromHexString (builtins.substring offset 2 hex)) / 255.0;
    in "Color(${toString (channel 1)}, ${toString (channel 3)}, ${toString (channel 5)}, 1)";

    interfaceSettings = {
      "interface/theme/color_preset" = ''"Custom"'';
      "interface/theme/use_system_accent_color" = "false";
      "interface/theme/base_color" = toGdColor theme.base00;
      "interface/theme/accent_color" = toGdColor theme.base0D;
      "interface/theme/contrast" = "0.3";
      "text_editor/theme/color_theme" = ''"gruvbox"'';
    };

    settingsFileName = "editor_settings-${lib.versions.majorMinor pkgs."godot-mono".version}.tres";

    upsertSettings =
      lib.concatStringsSep "\n"
      (lib.mapAttrsToList (key: value: ''
          if grep -q "^${key} = " "$settingsFile"; then
            sed -i 's|^${key} = .*|${key} = ${value}|' "$settingsFile"
          else
            echo '${key} = ${value}' >> "$settingsFile"
          fi
        '')
        interfaceSettings);

    installTheme = ''
      dataDir="''${XDG_CONFIG_HOME:-$HOME/.config}/godot"
      mkdir -p "$dataDir/text_editor_themes"
      ln -sfT ${syntaxTheme} "$dataDir/text_editor_themes/gruvbox.tet"

      settingsFile="$dataDir/${settingsFileName}"
      if [ ! -f "$settingsFile" ]; then
        printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$settingsFile"
      fi
      ${upsertSettings}
    '';
  in {
    imports = [wlib.modules.default];
    package = pkgs."godot-mono";

    runShell = [installTheme];
  };
}

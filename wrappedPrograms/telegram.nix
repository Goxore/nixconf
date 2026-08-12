{self, ...}: {
  flake.wrappers.telegram = {
    wlib,
    pkgs,
    lib,
    ...
  }: let
    inherit (self) theme darken;

    upstreamPalette = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/indev29/telegram-gruvbox/e111a4b0acd8f77f396c78781df5bea7970d996a/colors.tdesktop-theme";
      hash = "sha256-s/xkOx+WYrwFD8GffWfUvaUenU9gbS3ptlbw5ZTmuik=";
    };

    paletteConstants = {
      bg0_hard = theme.base00;
      bg0 = theme.base00;
      bg0_soft = theme.base01;
      bg1 = theme.base02;
      bg2 = theme.base03;
      bg3 = darken 45 theme.base04;
      bg4 = darken 33 theme.base04;

      overlay = "${theme.base00}80";
      overlay_hard = "${theme.base00}c0";

      neutral_gray = darken 22 theme.base04;

      fg = theme.base06;
      fg0 = theme.base07;
      fg1 = theme.base06;
      fg2 = theme.base05;
      fg3 = theme.base04;
      fg4 = darken 12 theme.base04;

      bright_red = theme.base08;
      bright_orange = theme.base09;
      bright_yellow = theme.base0A;
      bright_green = theme.base0B;
      bright_aqua = theme.base0C;
      bright_blue = theme.base0D;
      bright_purple = theme.base0E;

      neutral_orange = darken 25 theme.base09;
      neutral_yellow = darken 25 theme.base0A;
      neutral_green = darken 25 theme.base0B;
      neutral_aqua = darken 25 theme.base0C;
      neutral_purple = darken 25 theme.base0E;

      material_red = theme.base08;
      material_orange = theme.base0F;
      material_yellow = theme.base0A;
      material_green = theme.base0B;
      material_aqua = theme.base0C;
      material_blue = theme.base0D;
      material_purple = theme.base0E;

      none = "#00000000";
    };

    paletteOverrides = {
      msgInBg = theme.base00;
      msgOutBg = theme.base01;
      msgInBgSelected = theme.base02;
      msgOutBgSelected = theme.base02;
    };

    constantsBlock =
      pkgs.writeText "telegram-constants.tdesktop-theme"
      (lib.concatStringsSep "\n"
        (lib.mapAttrsToList (name: color: "${name}: ${color};") paletteConstants));

    backgroundBlur = "0x24";

    themeFile =
      pkgs.runCommand "gruvbox.tdesktop-theme" {
        nativeBuildInputs = [pkgs.zip pkgs.imagemagick];
      } ''
        mkdir contents
        cat ${constantsBlock} > contents/colors.tdesktop-theme
        sed -n '/^none: #00000000;/,$p' ${upstreamPalette} \
          | tail -n +2 >> contents/colors.tdesktop-theme

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (key: color: ''
            sed -i -E 's|^${key}: [^;]*;|${key}: ${color};|' contents/colors.tdesktop-theme
            grep -qE '^${key}: ${color};' contents/colors.tdesktop-theme || {
              echo "telegram palette: no ${key} key to override"
              exit 1
            }
          '')
          paletteOverrides)}

        undefined="$(grep -oE '^[a-zA-Z_0-9]+: *[a-zA-Z_0-9]+;' contents/colors.tdesktop-theme \
          | sed -E 's/^[a-zA-Z_0-9]+: *//; s/;$//' | sort -u \
          | while read -r ref; do
              grep -qE "^$ref: " contents/colors.tdesktop-theme || echo "$ref"
            done)"
        if [ -n "$undefined" ]; then
          echo "telegram palette references undefined constants:"
          echo "$undefined"
          exit 1
        fi

        magick ${self.wallpaper} -blur ${backgroundBlur} contents/background.png
        cd contents
        zip -q -X $out colors.tdesktop-theme background.png
      '';

    installTheme = ''
      themePath="$HOME/.local/share/TelegramDesktop/${themeFile.name}"
      if ! ${lib.getExe' pkgs.diffutils "cmp"} -s ${themeFile} "$themePath"; then
        install -Dm644 ${themeFile} "$themePath"
        (sleep 15; touch "$themePath") &
      fi
    '';
  in {
    imports = [wlib.modules.default];
    package = pkgs.telegram-desktop;

    runShell = [installTheme];
  };
}

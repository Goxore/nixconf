{self, ...}: let
  inherit (self) theme;
in {
  perSystem = {
    pkgs,
    self',
    ...
  }: {
    packages.terminal = self'.packages.kitty;

    packages.kitty = self.wrapperModules.kitty.apply {
      inherit pkgs;
      config = {
        enable_audio_bell = "no";

        font_size = 15;

        cursor_text_color = "background";

        allow_remote_control = "yes";
        shell_integration = "enabled";

        cursor_trail = 3;

        background = theme.base00;
        foreground = theme.base07;

        cursor = theme.base07;

        selection_foreground = theme.base02;
        selection_background = theme.base01;

        color0 = theme.base00;
        color8 = theme.base02;
        color1 = theme.base08;
        color9 = theme.base08;
        color2 = theme.base0B;
        color10 = theme.base0B;
        color3 = theme.base0A;
        color11 = theme.base0A;
        color4 = theme.base0D;
        color12 = theme.base0D;
        color5 = theme.base0E;
        color13 = theme.base0E;
        color6 = theme.base0C;
        color14 = theme.base0C;
        color7 = theme.base03;
        color15 = theme.base03;
      };
    };
  };
}

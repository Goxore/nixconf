{
  self,
  lib,
  ...
}: {
  wrappers.kitty = {
    wlib,
    config,
    ...
  }: {
    imports = [wlib.wrapperModules.kitty];

    options.shell = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    config = {
      settings =
        {
          enable_audio_bell = "no";

          font_size = 15;
          font_family = "JetBrainsMono Nerd Font";

          cursor_text_color = "background";

          allow_remote_control = "yes";
          shell_integration = "enabled";

          cursor_trail = 3;

          background = self.lib.theme.base00;
          foreground = self.lib.theme.base07;

          cursor = self.lib.theme.base07;

          selection_foreground = self.lib.theme.base02;
          selection_background = self.lib.theme.base01;

          active_tab_foreground = self.lib.theme.base0B;
          active_tab_background = self.lib.theme.base03;
          inactive_tab_background = self.lib.theme.base01;
        }
        // lib.listToAttrs (lib.imap0 (index: color: lib.nameValuePair "color${toString index}" color) self.lib.ansi)
        // lib.optionalAttrs (config.shell != "") {inherit (config) shell;};

      keybindings = {
        "alt+1" = "goto_tab 1";
        "alt+2" = "goto_tab 2";
        "alt+3" = "goto_tab 3";
        "alt+4" = "goto_tab 4";
        "alt+5" = "goto_tab 5";
        "alt+6" = "goto_tab 6";
        "alt+7" = "goto_tab 7";
        "alt+8" = "goto_tab 8";
        "alt+9" = "goto_tab 9";
        "ctrl+shift+w" = "close_tab";
        "ctrl+t" = "new_tab_with_cwd";
        "ctrl+shift+t" = "new_tab";
      };
    };
  };
}

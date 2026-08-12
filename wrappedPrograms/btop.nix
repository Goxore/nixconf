{self, ...}: {
  flake.wrappers.btop = {
    wlib,
    lib,
    ...
  }: let
    inherit (self) theme darken;

    themeColors = {
      main_bg = theme.base00;
      main_fg = theme.base06;
      title = theme.base07;
      hi_fg = theme.base0E;
      selected_bg = theme.base02;
      selected_fg = theme.base07;
      inactive_fg = theme.base03;
      graph_text = theme.base04;
      proc_misc = theme.base0C;

      cpu_box = theme.base02;
      mem_box = theme.base02;
      net_box = theme.base02;
      proc_box = theme.base02;
      div_line = theme.base02;

      temp_start = theme.base0B;
      temp_mid = theme.base0A;
      temp_end = theme.base08;

      cpu_start = theme.base0C;
      cpu_mid = theme.base0A;
      cpu_end = theme.base08;

      free_start = darken 40 theme.base0B;
      free_mid = darken 20 theme.base0B;
      free_end = theme.base0B;

      cached_start = darken 40 theme.base0D;
      cached_mid = darken 20 theme.base0D;
      cached_end = theme.base0D;

      available_start = darken 40 theme.base0A;
      available_mid = darken 20 theme.base0A;
      available_end = theme.base0A;

      used_start = darken 40 theme.base08;
      used_mid = darken 20 theme.base08;
      used_end = theme.base08;

      download_start = darken 40 theme.base0E;
      download_mid = darken 20 theme.base0E;
      download_end = theme.base0E;

      upload_start = darken 40 theme.base0C;
      upload_mid = darken 20 theme.base0C;
      upload_end = theme.base0C;
    };
  in {
    imports = [wlib.wrapperModules.btop];

    themes.gruvbox =
      lib.concatStringsSep "\n"
      (lib.mapAttrsToList (name: color: ''theme[${name}]="${color}"'') themeColors);

    settings = {
      color_theme = "gruvbox";
      theme_background = false;
      truecolor = true;
      vim_keys = true;
      rounded_corners = true;
      update_ms = 1000;
      proc_sorting = "cpu lazy";
      proc_tree = false;
      shown_boxes = "cpu mem net proc";
      graph_symbol = "braille";
      base_10_sizes = false;
      show_uptime = true;
      check_temp = true;
      show_battery = true;
      log_level = "WARNING";
    };
  };
}

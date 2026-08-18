{lib, ...}: let
  theme = {
    base00 = "#181818"; # bg
    base01 = "#282828"; # dark
    base02 = "#3c3836";
    base03 = "#504945";
    base04 = "#bdae93";
    base05 = "#d5c4a1";
    base06 = "#ebdbb2"; # fg
    base07 = "#fbf1c7"; # light fg
    base08 = "#fb4934"; # red
    base09 = "#fe8019"; # orange
    base0A = "#fabd2f"; # yellow
    base0B = "#b8bb26"; # green
    base0C = "#8ec07c"; # cyan
    base0D = "#7daea3"; # blue
    base0E = "#e089a1"; # magenta
    base0F = "#f28534"; # orange
  };

  stripHash = str:
    if builtins.substring 0 1 str == "#"
    then builtins.substring 1 (builtins.stringLength str - 1) str
    else str;

  themeNoHash = builtins.mapAttrs (_: v: stripHash v) theme;

  darken = percent: hex: let
    channel = offset: let
      value = lib.fromHexString (builtins.substring offset 2 (stripHash hex));
    in
      lib.toLower (lib.fixedWidthString 2 "0" (lib.toHexString (value * (100 - percent) / 100)));
  in "#${channel 0}${channel 2}${channel 4}";
  cursor = {
    name = "Bibata-Gruvbox";
    size = 24;
  };
in {
  flake = {
    inherit theme themeNoHash darken cursor;
  };
}

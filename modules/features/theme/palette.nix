{lib, ...}: let
  theme = {
    base00 = "#181818";
    base01 = "#282828";
    base02 = "#3c3836";
    base03 = "#504945";
    base04 = "#bdae93";
    base05 = "#d5c4a1";
    base06 = "#ebdbb2";
    base07 = "#fbf1c7";
    base08 = "#fb4934";
    base09 = "#fe8019";
    base0A = "#fabd2f";
    base0B = "#b8bb26";
    base0C = "#8ec07c";
    base0D = "#7daea3";
    base0E = "#e089a1";
    base0F = "#f28534";
  };

  stripHash = str:
    if builtins.substring 0 1 str == "#"
    then builtins.substring 1 (builtins.stringLength str - 1) str
    else str;

  themeNoHash = builtins.mapAttrs (_: stripHash) theme;

  darken = percent: hex: let
    channel = offset: let
      value = lib.fromHexString (builtins.substring offset 2 (stripHash hex));
    in
      lib.toLower (lib.fixedWidthString 2 "0" (lib.toHexString (value * (100 - percent) / 100)));
  in "#${channel 0}${channel 2}${channel 4}";

  mix = from: to: percent: let
    channel = offset: let
      start = lib.fromHexString (builtins.substring offset 2 (stripHash from));
      end = lib.fromHexString (builtins.substring offset 2 (stripHash to));
    in
      lib.toLower (lib.fixedWidthString 2 "0" (lib.toHexString ((start * (100 - percent) + end * percent + 50) / 100)));
  in "#${channel 0}${channel 2}${channel 4}";

  role = color: ink: container: inkContainer: {
    inherit color ink container inkContainer;
  };

  accent = color: containerShare: inkShare:
    role color theme.base00 (mix color theme.base00 containerShare) (mix color theme.base07 inkShare);

  tones = {
    primary = accent theme.base0D 72 45;
    secondary = accent theme.base0C 74 42;
    tertiary = accent theme.base0E 72 42;
    error = accent theme.base08 74 45;
    warning = accent theme.base09 74 45;
    success = accent theme.base0B 78 45;
  };

  capital = name: lib.toUpper (builtins.substring 0 1 name) + builtins.substring 1 (-1) name;

  surface = theme.base00;
  inkSurfaceVariant = theme.base04;

  material =
    lib.concatMapAttrs (name: tone: {
      ${name} = tone.color;
      "ink${capital name}" = tone.ink;
      "${name}Container" = tone.container;
      "ink${capital name}Container" = tone.inkContainer;
    })
    tones
    // {
      inherit surface inkSurfaceVariant;
      surfaceContainerLow = mix theme.base00 theme.base01 45;
      surfaceContainer = theme.base01;
      surfaceContainerHigh = mix theme.base01 theme.base02 70;
      surfaceContainerHighest = theme.base02;
      inkSurface = theme.base07;
      outline = mix theme.base03 theme.base04 40;
      outlineVariant = theme.base03;
      inverseSurface = theme.base06;
      inkInverseSurface = theme.base00;
      disabledContent = mix surface inkSurfaceVariant 55;
      disabledContainer = mix surface theme.base07 10;
      disabledOutline = mix surface theme.base07 18;
    };

  ansiSlots = [
    "base00"
    "base08"
    "base0B"
    "base0A"
    "base0D"
    "base0E"
    "base0C"
    "base05"
    "base03"
    "base08"
    "base0B"
    "base0A"
    "base0D"
    "base0E"
    "base0C"
    "base07"
  ];

  cursor = {
    name = "Bibata-Gruvbox";
    size = 24;
  };
in {
  lib = {
    inherit theme themeNoHash darken mix material cursor;

    ansi = map (slot: theme.${slot}) ansiSlots;
    ansiNoHash = map (slot: themeNoHash.${slot}) ansiSlots;
  };
}

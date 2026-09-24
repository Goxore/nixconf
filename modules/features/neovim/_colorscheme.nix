{
  theme,
  darken,
}: let
  inherit (builtins) concatStringsSep;

  palette =
    theme
    // {
      green = theme.base0B;
      cyan = theme.base0C;
      blue2 = darken 25 theme.base0D;

      bg = theme.base00;
      fg = theme.base06;
      orange = theme.base09;
      red = theme.base08;
      blue = theme.base0D;
      yellow = theme.base0A;
      magenta = theme.base0E;

      gray = theme.base01;
      lightgray = theme.base02;
      darkgray = darken 15 theme.base00;
      inactivegray = darken 30 theme.base00;
    };

  groups = [
    [
      "base00"
      "base01"
      "base02"
      "base03"
      "base04"
      "base05"
      "base06"
      "base07"
      "base08"
      "base09"
      "base0A"
      "base0B"
      "base0C"
      "base0D"
      "base0E"
      "base0F"
    ]
    [
      "green"
      "cyan"
      "blue2"
    ]
    [
      "bg"
      "fg"
      "orange"
      "red"
      "blue"
      "yellow"
      "magenta"
      "gray"
      "lightgray"
      "darkgray"
      "inactivegray"
    ]
  ];

  entry = name: "    ${name} = \"${palette.${name}}\",";

  renderGroup = names: concatStringsSep "\n" (map entry names);
in
  concatStringsSep "\n" [
    "local COLORSCHEME = {"
    (concatStringsSep "\n\n" (map renderGroup groups))
    "}"
    ""
    "return COLORSCHEME"
    ""
  ]

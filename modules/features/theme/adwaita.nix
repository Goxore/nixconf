{self, ...}: let
  inherit (self.lib) theme darken;
in {
  lib.adwaita = {
    accentBg = theme.base0B;
    accentFg = theme.base00;

    destructiveBg = theme.base08;
    destructiveFg = theme.base00;

    successBg = theme.base0B;
    successFg = theme.base00;

    warningBg = theme.base0A;
    warningFg = theme.base00;

    errorBg = theme.base08;
    errorFg = theme.base00;

    windowBg = theme.base00;
    windowFg = theme.base06;

    viewBg = darken 30 theme.base00;
    viewFg = theme.base06;

    headerbarBg = theme.base01;
    headerbarFg = theme.base06;
    headerbarBorder = theme.base02;
    headerbarBackdrop = theme.base00;
    headerbarShade = "rgba(0, 0, 0, 0.36)";

    sidebarBg = theme.base01;
    sidebarFg = theme.base06;
    sidebarBackdrop = theme.base00;
    sidebarShade = "rgba(0, 0, 0, 0.36)";

    secondarySidebarBg = theme.base01;
    secondarySidebarFg = theme.base06;
    secondarySidebarBackdrop = theme.base00;
    secondarySidebarShade = "rgba(0, 0, 0, 0.36)";

    cardBg = theme.base02;
    cardFg = theme.base06;
    cardShade = "rgba(0, 0, 0, 0.36)";

    dialogBg = theme.base01;
    dialogFg = theme.base06;

    popoverBg = theme.base01;
    popoverFg = theme.base06;
    popoverShade = "rgba(0, 0, 0, 0.25)";

    thumbnailBg = theme.base01;
    thumbnailFg = theme.base06;

    shade = "rgba(0, 0, 0, 0.25)";
    scrollbarOutline = theme.base02;
  };
}

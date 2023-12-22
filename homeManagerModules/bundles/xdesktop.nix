{pkgs, ...}: {
  home.packages = with pkgs; [
    xclip
    sxhkd

    xorg.xev
    xorg.xbacklight
    xorg.xhost

    maim
    xdotool
    devour
    ueberzug
    pkgs.picom-jonaburg
    devour
  ];
}

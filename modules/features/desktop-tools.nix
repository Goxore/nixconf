{
  modules.nixos.desktop = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.pcmanfm
      pkgs.wl-clipboard
      pkgs.mpv
    ];
  };
}

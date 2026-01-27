{
  flake.nixosModules.wallpaper = {
    pkgs,
    lib,
    ...
  }: {
    preferences.autostart = [
      ''
        ${pkgs.swww}/bin/swww-daemon &
        ${lib.getExe pkgs.swww} img ${./gruvbox-mountain-village.png} &
      ''
    ];
  };
}

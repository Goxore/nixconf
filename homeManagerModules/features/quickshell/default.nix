{
  pkgs,
  lib,
  ...
}: {
  xdg.configFile."quickshell" = {
    source = ./.;
    recursive = true;
  };

  myHomeManager = {
    startScripts.quickshell = pkgs.quickshell;

    keybinds = {
      # toggle player window
      "$mainMod, M".script = ''
        ${lib.getExe pkgs.quickshell} ipc call musicLyricsService setVisible 1
      '';
      "$mainMod SHIFT, M".script = ''
        ${lib.getExe pkgs.quickshell} ipc call musicLyricsService setVisible 0
      '';
    };
  };
}

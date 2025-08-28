{
  pkgs,
  lib,
  ...
}: {
  xdg.configFile."quickshell" = {
    source = ./.;
    recursive = true;
  };

  myHomeManager.startScripts.quickshell = pkgs.quickshell;
}

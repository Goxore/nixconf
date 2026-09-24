{
  modules.nixos.base = {
    persistence.cache.directories = [
      ".config/Bitwarden CLI"
    ];
  };

  modules.nixos.desktop = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.vj.screenshot
      pkgs.vj.screenshotRegion
      pkgs.vj.pipeSwappy
      pkgs.vj.vol
      pkgs.vj.volYtMusic
    ];
  };
}

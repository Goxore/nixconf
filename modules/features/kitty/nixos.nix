{
  modules.nixos.desktop = {pkgs, ...}: {
    environment.systemPackages = [pkgs.vj.terminal];
  };
}

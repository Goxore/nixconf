{
  modules.nixos.desktop = {pkgs, ...}: {
    programs.mango.enable = true;
    programs.mango.package = pkgs.vj.mangowcDynamic;

    environment.etc."mango/config.conf".source = "${pkgs.vj.mangowcDynamic}/config.conf";
  };
}

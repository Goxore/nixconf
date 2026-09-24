{
  modules.nixos.personal = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.vj.vesktop
      pkgs.vj.vesktop-alt
      pkgs.discord
    ];

    persistence.cache.directories = [
      ".config/vesktop"
      ".config/vesktop-alt"
    ];
  };
}

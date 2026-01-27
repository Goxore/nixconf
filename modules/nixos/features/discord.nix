{
  flake.nixosModules.discord = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.vesktop
      pkgs.discord
    ];

    persistance.cache.directories = [
      ".config/vesktop"
    ];
  };
}

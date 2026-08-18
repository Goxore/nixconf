{
  flake.nixosModules.gimp = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.gimp3
    ];

    persistance.cache.directories = [
      ".config/GIMP"
    ];
  };
}

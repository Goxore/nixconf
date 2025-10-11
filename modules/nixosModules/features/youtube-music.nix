{
  flake.nixosModules.youtube-music = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.youtube-music
    ];

    persistance.cache.directories = [
      ".config/YouTube Music"
    ];
  };
}

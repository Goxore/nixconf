{
  modules.nixos.personal = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.pear-desktop
    ];

    persistence.cache.directories = [
      ".config/YouTube Music"
    ];
  };
}

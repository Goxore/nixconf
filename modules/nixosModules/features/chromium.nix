{
  flake.nixosModules.chromium = {pkgs, ...}: {
    programs.chromium.enable = true;

    environment.systemPackages = [
      pkgs.ungoogled-chromium
    ];

    persistance.cache.directories = [
      ".config/chromium"
    ];
  };
}

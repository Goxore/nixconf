{
  modules.nixos.desktop = {pkgs, ...}: {
    programs.chromium.enable = true;

    environment.systemPackages = [
      pkgs.ungoogled-chromium
    ];

    persistence.cache.directories = [
      ".config/chromium"
    ];
  };
}

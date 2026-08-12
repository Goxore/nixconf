{self, ...}: {
  flake.nixosModules.telegram = {pkgs, ...}: {
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.telegram
    ];

    persistance.cache.directories = [
      ".local/share/TelegramDesktop"
    ];
  };
}

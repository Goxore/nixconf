{
  flake.nixosModules.telegram = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.telegram-desktop
    ];

    persistance.cache.directories = [
      ".local/share/TelegramDesktop"
    ];
  };
}

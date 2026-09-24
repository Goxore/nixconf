{
  modules.nixos.personal = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.vj.telegram
    ];

    persistence.cache.directories = [".local/share/TelegramDesktop"];
  };
}

{
  flake.nixosModules.firefox = {pkgs, ...}: {
    programs.firefox.enable = true;

    persistance.data.directories = [
      ".mozilla"
    ];

    persistance.cache.directories = [
      ".cache/mozilla"
    ];

    preferences.keymap = {
      "SUPER + d"."f".package = pkgs.firefox;
    };
  };
}

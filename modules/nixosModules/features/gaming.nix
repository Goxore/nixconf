{
  flake.nixosModules.gaming = {
    pkgs,
    lib,
    ...
  }: let
    inherit (lib) mkDefault;
  in {
    hardware.graphics.enable = mkDefault true;

    programs = {
      gamemode.enable = true;
      gamescope.enable = true;
      steam = {
        enable = true;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
        extraPackages = with pkgs; [
          SDL2
          gamescope
          er-patcher
        ];
        protontricks.enable = true;
      };
    };

    environment.systemPackages = with pkgs; [
      lutris
      steam-run
      dxvk
      # parsec-bin

      gamescope

      mangohud

      r2modman

      heroic

      er-patcher
      bottles

      steamtinkerlaunch

      prismlauncher

      lsfg-vk
      lsfg-vk-ui
    ];

    services.zerotierone.enable = true;

    persistance.cache.directories = [
      ".local/share/Hytale"
      ".local/share/hytale-launcher"

      ".local/share/Steam"
      ".local/share/bottles"
      ".local/share/PrismLauncher"
      ".config/r2modmanPlus-local"

      ".local/share/Terraria"

      "Games"

      ".config/heroic"
    ];
  };
}

{
  flake.nixosModules.gaming = {
    pkgs,
    lib,
    ...
  }: let
    inherit (lib) mkDefault;
  in {
    hardware.graphics.enable = mkDefault true;
    hardware.graphics.extraPackages = with pkgs; [
      amdvlk
    ];
    hardware.graphics.extraPackages32 = with pkgs; [
      driversi686Linux.amdvlk
    ];

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
    ];

    persistance.cache.directories = [
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

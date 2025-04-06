{
  pkgs,
  lib,
  ...
}: {
  home.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
  };

  programs.mangohud.enable = true;

  home.packages = with pkgs; [
    lutris
    steam
    steam-run
    protonup-ng
    gamemode
    dxvk
    # parsec-bin

    gamescope

    # heroic
    mangohud

    r2modman

    heroic

    er-patcher
    bottles

    steamtinkerlaunch
  ];

  myHomeManager.impermanence.cache.directories = [
    ".local/share/Steam"
    ".local/share/bottles"
    ".config/r2modmanPlus-local"

    ".local/share/Terraria"

    "Games"

    ".config/heroic"
  ];
}

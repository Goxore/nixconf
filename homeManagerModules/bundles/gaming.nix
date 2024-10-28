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

    steamPackages.steam-runtime
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

    "Games"

    ".config/heroic"

  ];
}

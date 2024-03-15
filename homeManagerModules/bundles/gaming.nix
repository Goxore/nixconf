{pkgs, ...}: {
  home.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
  };

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
  ];

  myHomeManager.impermanence.directories = [
    ".local/share/Steam"
    ".config/r2modmanPlus-local"
  ];
}

{self, inputs, ...}: {
  flake.nixosModules.gaming = {
    pkgs,
    lib,
    ...
  }: let
    inherit (self) theme darken;

    adwaitaForSteam = pkgs.fetchFromGitHub {
      owner = "tkashkin";
      repo = "Adwaita-for-Steam";
      rev = "1e92107a51f6ed53c59c38646444c9eb3a52b030";
      hash = "sha256-wH0z2LZ94j5ErRI40f9IRBJXJ6yuL+NLgjmj9G8odxU=";
    };

    steamPalette = pkgs.writeText "steam-palette.css" ''
      :root
      {
        --adw-color-scheme: dark !important;

        --adw-accent-bg-light: var(--adw-system-accent, ${theme.base0B}) !important;
        --adw-accent-bg-dark: var(--adw-system-accent, ${theme.base0B}) !important;
        --adw-accent-fg: ${theme.base00} !important;

        --adw-destructive-bg-light: ${theme.base08} !important;
        --adw-destructive-bg-dark: ${theme.base08} !important;
        --adw-destructive-fg: ${theme.base00} !important;

        --adw-success-bg-light: ${theme.base0B} !important;
        --adw-success-bg-dark: ${theme.base0B} !important;
        --adw-success-fg: ${theme.base00} !important;

        --adw-warning-bg-light: ${theme.base0A} !important;
        --adw-warning-bg-dark: ${theme.base0A} !important;
        --adw-warning-fg: ${theme.base00} !important;

        --adw-error-bg-light: ${theme.base08} !important;
        --adw-error-bg-dark: ${theme.base08} !important;
        --adw-error-fg: ${theme.base00} !important;

        --adw-window-bg: ${theme.base00} !important;
        --adw-window-fg: ${theme.base06} !important;

        --adw-view-bg: ${darken 30 theme.base00} !important;
        --adw-view-fg: ${theme.base06} !important;

        --adw-headerbar-bg: ${theme.base01} !important;
        --adw-headerbar-fg: ${theme.base06} !important;
        --adw-headerbar-backdrop: ${theme.base00} !important;
        --adw-headerbar-shade: rgba(0, 0, 0, 0.36) !important;
        --adw-headerbar-darker-shade: rgba(0, 0, 0, 0.9) !important;

        --adw-sidebar-bg: ${theme.base01} !important;
        --adw-sidebar-fg: ${theme.base06} !important;
        --adw-sidebar-backdrop: ${theme.base00} !important;
        --adw-sidebar-shade: rgba(0, 0, 0, 0.36) !important;

        --adw-secondary-sidebar-bg: ${theme.base01} !important;
        --adw-secondary-sidebar-fg: ${theme.base06} !important;
        --adw-secondary-sidebar-backdrop: ${theme.base00} !important;
        --adw-secondary-sidebar-shade: rgba(0, 0, 0, 0.36) !important;

        --adw-card-bg: ${theme.base02} !important;
        --adw-card-fg: ${theme.base06} !important;
        --adw-card-shade: rgba(0, 0, 0, 0.36) !important;

        --adw-dialog-bg: ${theme.base01} !important;
        --adw-dialog-fg: ${theme.base06} !important;

        --adw-popover-bg: ${theme.base01} !important;
        --adw-popover-fg: ${theme.base06} !important;
        --adw-popover-shade: rgba(0, 0, 0, 0.25) !important;

        --adw-thumbnail-bg: ${theme.base01} !important;
        --adw-thumbnail-fg: ${theme.base06} !important;

        --adw-shade: rgba(0, 0, 0, 0.25) !important;
        --adw-banner: ${theme.base03} !important;

        --adw-user-offline: ${theme.base03} !important;
        --adw-user-online: ${theme.base0D} !important;
        --adw-user-ingame: ${theme.base0B} !important;
      }
    '';

    installSteamSkin = ''
      steamRoot="$HOME/.local/share/Steam"
      if [ -d "$steamRoot/steamui/css" ]; then
        skinSource="$(${lib.getExe' pkgs.coreutils "mktemp"} -d -t adwaita-for-steam.XXXXXXXX)"
        if [ -n "$skinSource" ] && [ -d "$skinSource" ]; then
          cp -r ${adwaitaForSteam}/. "$skinSource"
          cp ${steamPalette} "$skinSource/custom.css"
          chmod -R u+w "$skinSource"

          (cd "$skinSource" && ${lib.getExe pkgs.python3} install.py \
            --target "$steamRoot" \
            --color-theme adwaita \
            --color-scheme dark \
            --accent-color "${theme.base0B}" \
            --custom-css "$skinSource/custom.css") || true

          chmod -R u+w "$steamRoot/steamui/adwaita" || true
          rm -rf -- "$skinSource"
        fi
      fi
    '';
  in {
    hardware.graphics.enable = lib.mkDefault true;

    programs = {
      gamemode.enable = true;
      gamescope.enable = true;
      steam = {
        package = pkgs.steam.override {
          extraProfile = installSteamSkin;
        };
        enable = true;
        # extraCompatPackages = with pkgs; [
        #   proton-ge-bin
        # ];
        # extraPackages = with pkgs; [
        #   SDL2
        #   gamescope
        #   er-patcher
        # ];
        protontricks.enable = true;
      };
    };

    environment.systemPackages = with pkgs; [
      steam-run
      dxvk
      # parsec-bin

      gamescope

      mangohud

      r2modman

      heroic

      er-patcher

      steamtinkerlaunch

      inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.bottles
      inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.prismlauncher

      lsfg-vk
      lsfg-vk-ui
      self.packages.${pkgs.stdenv.hostPlatform.system}.wow-launcher
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

    nix.settings = {
      substituters = ["https://nix-gaming.cachix.org"];
      trusted-public-keys = ["nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="];
    };
  };

  perSystem = {pkgs, ...}: {
    packages.wow-launcher = pkgs.writeShellApplication {
      name = "wow-launcher";

      runtimeInputs = with pkgs; [
        inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.wine-tkg
        # (wineWow64Packages.full.override {
        #   wineRelease = "staging";
        #   mingwSupport = true;
        # })
        winetricks
        vulkan-loader
        dxvk
      ];

      # todo: fix
      text = ''
        export WINEPREFIX="$HOME/Games/Wow"
        export WINEARCH=win64
        export WINEDEBUG="-all"
        export DRI_PRIME=1
        export DXVK_HUD=1
        export DXVK_DEVICE_SELECT=1

        BNET_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
        WOW_EXE="$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft/_retail_/Wow.exe"
        INSTALLER="Battle.net-Setup.exe"

        if [ ! -d "$WINEPREFIX" ]; then
          echo "Initializing new Wine prefix..."
          mkdir -p "$WINEPREFIX"
          wineboot -u
        fi

        if [ -f "$WOW_EXE" ]; then
          echo "Launching WoW via DXVK..."
          wine "$WOW_EXE"
          exit 0
        fi

        if [ ! -f "$BNET_EXE" ]; then
          if [ -f "$INSTALLER" ]; then
            wine "$INSTALLER"
          else
            echo "Installer not found. Please download Battle.net-Setup.exe"
            exit 1
          fi
        else
          wine "$BNET_EXE"
        fi
      '';
    };
  };
}

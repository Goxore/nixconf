{
  self,
  inputs,
  ...
}: {
  modules.nixos.gaming = {
    pkgs,
    lib,
    ...
  }: let
    inherit (self.lib) theme;

    adw = self.lib.adwaita;

    adwaitaForSteam = inputs.adwaita-for-steam;

    steamPalette = pkgs.writeText "steam-palette.css" ''
      :root
      {
        --adw-color-scheme: dark !important;

        --adw-accent-bg-light: var(--adw-system-accent, ${adw.accentBg}) !important;
        --adw-accent-bg-dark: var(--adw-system-accent, ${adw.accentBg}) !important;
        --adw-accent-fg: ${adw.accentFg} !important;

        --adw-destructive-bg-light: ${adw.destructiveBg} !important;
        --adw-destructive-bg-dark: ${adw.destructiveBg} !important;
        --adw-destructive-fg: ${adw.destructiveFg} !important;

        --adw-success-bg-light: ${adw.successBg} !important;
        --adw-success-bg-dark: ${adw.successBg} !important;
        --adw-success-fg: ${adw.successFg} !important;

        --adw-warning-bg-light: ${adw.warningBg} !important;
        --adw-warning-bg-dark: ${adw.warningBg} !important;
        --adw-warning-fg: ${adw.warningFg} !important;

        --adw-error-bg-light: ${adw.errorBg} !important;
        --adw-error-bg-dark: ${adw.errorBg} !important;
        --adw-error-fg: ${adw.errorFg} !important;

        --adw-window-bg: ${adw.windowBg} !important;
        --adw-window-fg: ${adw.windowFg} !important;

        --adw-view-bg: ${adw.viewBg} !important;
        --adw-view-fg: ${adw.viewFg} !important;

        --adw-headerbar-bg: ${adw.headerbarBg} !important;
        --adw-headerbar-fg: ${adw.headerbarFg} !important;
        --adw-headerbar-backdrop: ${adw.headerbarBackdrop} !important;
        --adw-headerbar-shade: ${adw.headerbarShade} !important;
        --adw-headerbar-darker-shade: rgba(0, 0, 0, 0.9) !important;

        --adw-sidebar-bg: ${adw.sidebarBg} !important;
        --adw-sidebar-fg: ${adw.sidebarFg} !important;
        --adw-sidebar-backdrop: ${adw.sidebarBackdrop} !important;
        --adw-sidebar-shade: ${adw.sidebarShade} !important;

        --adw-secondary-sidebar-bg: ${adw.secondarySidebarBg} !important;
        --adw-secondary-sidebar-fg: ${adw.secondarySidebarFg} !important;
        --adw-secondary-sidebar-backdrop: ${adw.secondarySidebarBackdrop} !important;
        --adw-secondary-sidebar-shade: ${adw.secondarySidebarShade} !important;

        --adw-card-bg: ${adw.cardBg} !important;
        --adw-card-fg: ${adw.cardFg} !important;
        --adw-card-shade: ${adw.cardShade} !important;

        --adw-dialog-bg: ${adw.dialogBg} !important;
        --adw-dialog-fg: ${adw.dialogFg} !important;

        --adw-popover-bg: ${adw.popoverBg} !important;
        --adw-popover-fg: ${adw.popoverFg} !important;
        --adw-popover-shade: ${adw.popoverShade} !important;

        --adw-thumbnail-bg: ${adw.thumbnailBg} !important;
        --adw-thumbnail-fg: ${adw.thumbnailFg} !important;

        --adw-shade: ${adw.shade} !important;
        --adw-banner: ${theme.base03} !important;

        --adw-user-offline: ${theme.base03} !important;
        --adw-user-online: ${theme.base0D} !important;
        --adw-user-ingame: ${adw.accentBg} !important;
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
          extraArgs = "-wayland";
          extraProfile = installSteamSkin;
        };
        enable = true;
        protontricks.enable = true;
      };
    };

    environment.systemPackages = [
      pkgs.steam-run
      pkgs.dxvk

      pkgs.gamescope

      pkgs.mangohud

      pkgs.r2modman

      pkgs.heroic

      pkgs.er-patcher

      pkgs.steamtinkerlaunch

      pkgs.bottles
      pkgs.prismlauncher

      pkgs.lsfg-vk
      pkgs.lsfg-vk-ui
      pkgs.vj.wow-launcher
    ];

    services.zerotierone.enable = true;
    persistence.directories = ["/var/lib/zerotier-one"];

    persistence.cache.directories = [
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

  packages = pkgs: {
    wow-launcher = pkgs.writeShellApplication {
      name = "wow-launcher";

      runtimeInputs = [
        inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.wine-tkg
        pkgs.winetricks
        pkgs.vulkan-loader
        pkgs.dxvk
      ];

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

{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];
  stylix = {
    base16Scheme = {
      base00 = "242424"; # ----
      base01 = "3c3836"; # ---
      base02 = "504945"; # --
      base03 = "665c54"; # -
      base04 = "bdae93"; # +
      base05 = "d5c4a1"; # ++
      base06 = "ebdbb2"; # +++
      base07 = "fbf1c7"; # ++++
      base08 = "fb4934"; # red
      base09 = "fe8019"; # orange
      base0A = "fabd2f"; # yellow
      base0B = "b8bb26"; # green
      base0C = "8ec07c"; # aqua/cyan
      base0D = "7daea3"; # blue
      base0E = "e089a1"; # purple
      base0F = "f28534"; # brown
    };

    image = ./gruvbox-mountain-village.png;

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };

      sizes = {
        applications = 12;
        terminal = 15;
        desktop = 10;
        popups = 10;
      };
    };

    cursor.name = "Banana-Gruvbox";
    # cursor.package = pkgs.bibata-cursors;

    cursor.package = let
      banana = pkgs.stdenv.mkDerivation {
        name = "banana-cursor";

        src = builtins.fetchurl {
          url = "https://github.com/vimjoyer/banana-cursor-gruvbox/releases/download/4/Banana-Gruvbox.tar.gz";
          sha256 = "sha256-opGDdW7w2eAhwP/fuBES3qA6d7M8I/xhdXiTXoIoGzs=";
        };
        unpack = false;

        installPhase = ''
          mkdir -p $out/share/icons/Banana-Gruvbox
          tar -xvf $src -C $out/share/icons/Banana-Gruvbox
        '';
      };
    in
      banana;

    targets.chromium.enable = true;
    targets.grub.enable = true;
    targets.grub.useImage = true;
    targets.plymouth.enable = true;

    # opacity.terminal = 1;
    # stylix.targets.nixos-icons.enable = true;

    autoEnable = false;
  };
}

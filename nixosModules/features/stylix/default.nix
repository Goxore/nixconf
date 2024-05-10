{pkgs, inputs, ...}: {

  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  stylix.base16Scheme = {
    base00 = "282828"; # ----
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
    base0D = "83a598"; # blue
    base0E = "d3869b"; # purple
    base0F = "d65d0e"; # brown
  };

  stylix.image = ./gruvbox-mountain-village.png;

  stylix.fonts.monospace.package = pkgs.nerdfonts.override {fonts = ["JetBrainsMono"];};
  stylix.fonts.monospace.name = "JetBrainsMono Nerd Font Mono";
  stylix.fonts.sizes.terminal = 15;

  stylix.cursor.name = "Bibata-Modern-Ice";
  stylix.cursor.package = pkgs.bibata-cursors;

  stylix.targets.chromium.enable = true;
  stylix.targets.grub.enable = true;
  # stylix.targets.nixos-icons.enable = true;

  stylix.autoEnable = false;
}

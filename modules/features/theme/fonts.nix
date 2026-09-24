{
  modules.nixos.desktop = {pkgs, ...}: {
    fonts.packages = [
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.ubuntu-sans
      pkgs.cm_unicode
      pkgs.corefonts
      pkgs.unifont
      pkgs.material-symbols
      pkgs.noto-fonts-color-emoji
    ];

    fonts.fontconfig.defaultFonts = {
      serif = ["Ubuntu Sans"];
      sansSerif = ["Ubuntu Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
      emoji = ["Noto Color Emoji"];
    };
  };
}

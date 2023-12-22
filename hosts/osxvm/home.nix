{
  inputs,
  pkgs,
  ...
}:
# ================================================================ #
# =                           OUTDATED                           = #
# ================================================================ #
{
  imports = [
    ./features/general.nix
    ./features/programs/alacritty.nix
  ];

  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

  fonts.fontconfig.enable = true;

  home = {
    username = "yurii";
    stateVersion = "22.11";
    homeDirectory = "/Users/yurii/";

    packages = with pkgs; [
      (pkgs.nerdfonts.override {fonts = ["JetBrainsMono" "Iosevka" "FiraCode"];})
    ];
  };
}

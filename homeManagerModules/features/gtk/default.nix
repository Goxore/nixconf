{
  config,
  inputs,
  ...
}: let
  pkgs = inputs.nixpkgsold.legacyPackages."x86_64-linux";
in {
  home.file = {
    ".local/share/icons/GruvboxPlus".source = "${pkgs.gruvbox-plus-icons}/share/icons/Gruvbox-Plus-Dark";
  };

  gtk.enable = true;
  gtk.iconTheme.package = pkgs.gruvbox-plus-icons;
  gtk.iconTheme.name = "GruvboxPlus";
}

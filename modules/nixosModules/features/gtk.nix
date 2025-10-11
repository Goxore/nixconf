{
  flake.nixosModules.gtk = {
    pkgs,
    lib,
    ...
  }: let
    inherit (lib) mkDefault;

    theme-name = "Gruvbox-Green-Dark-Medium";
    theme-package = pkgs.gruvbox-gtk-theme.override {
      colorVariants = ["dark"];
      sizeVariants = ["standard"];
      themeVariants = ["green"];
      tweakVariants = ["medium" "macos"];
    };

    icon-theme-package = pkgs.gruvbox-plus-icons;
    icon-theme-name = "Gruvbox-Plus-Dark";

    gtksettings = ''
      [Settings]
      gtk-icon-theme-name = ${icon-theme-name}
      gtk-theme-name = ${theme-name}
    '';
  in {
    environment = {
      etc = {
        "xdg/gtk-3.0/settings.ini".text = gtksettings;
        "xdg/gtk-4.0/settings.ini".text = gtksettings;
      };
    };

    environment.variables = {
      GTK_THEME = theme-name;
    };

    programs = {
      dconf = {
        enable = mkDefault true;
        profiles = {
          user = {
            databases = [
              {
                lockAll = false;
                settings = {
                  "org/gnome/desktop/interface" = {
                    gtk-theme = theme-name;
                    icon-theme = icon-theme-name;
                    color-scheme = "prefer-dark";
                  };
                };
              }
            ];
          };
        };
      };
    };

    environment.systemPackages = [
      theme-package
      icon-theme-package

      pkgs.gtk3
      pkgs.gtk4
    ];
  };
}

{self, ...}: {
  flake.nixosModules.gtk = {
    pkgs,
    lib,
    config,
    ...
  }: let
    inherit (self) theme darken;

    theme-name = "adw-gtk3-dark";
    theme-package = pkgs.adw-gtk3;

    icon-theme-package = pkgs.gruvbox-plus-icons;
    icon-theme-name = "Gruvbox-Plus-Dark";

    cursor-theme-package = self.packages.${pkgs.stdenv.hostPlatform.system}.cursors;
    cursor-theme-name = self.cursor.name;
    cursor-size = self.cursor.size;

    font-name = "Ubuntu Sans 11";
    monospace-font-name = "JetBrainsMono Nerd Font 11";

    gtksettings = ''
      [Settings]
      gtk-icon-theme-name = ${icon-theme-name}
      gtk-theme-name = ${theme-name}
      gtk-cursor-theme-name = ${cursor-theme-name}
      gtk-cursor-theme-size = ${toString cursor-size}
      gtk-font-name = ${font-name}
      gtk-application-prefer-dark-theme = 1
    '';

    palette = ''
      @define-color accent_color ${theme.base0B};
      @define-color accent_bg_color ${theme.base0B};
      @define-color accent_fg_color ${theme.base00};

      @define-color destructive_color ${theme.base08};
      @define-color destructive_bg_color ${theme.base08};
      @define-color destructive_fg_color ${theme.base00};

      @define-color success_color ${theme.base0B};
      @define-color success_bg_color ${theme.base0B};
      @define-color success_fg_color ${theme.base00};

      @define-color warning_color ${theme.base0A};
      @define-color warning_bg_color ${theme.base0A};
      @define-color warning_fg_color ${theme.base00};

      @define-color error_color ${theme.base08};
      @define-color error_bg_color ${theme.base08};
      @define-color error_fg_color ${theme.base00};

      @define-color window_bg_color ${theme.base00};
      @define-color window_fg_color ${theme.base06};

      @define-color view_bg_color ${darken 30 theme.base00};
      @define-color view_fg_color ${theme.base06};

      @define-color headerbar_bg_color ${theme.base01};
      @define-color headerbar_fg_color ${theme.base06};
      @define-color headerbar_border_color ${theme.base02};
      @define-color headerbar_backdrop_color ${theme.base00};
      @define-color headerbar_shade_color rgba(0, 0, 0, 0.36);

      @define-color sidebar_bg_color ${theme.base01};
      @define-color sidebar_fg_color ${theme.base06};
      @define-color sidebar_backdrop_color ${theme.base00};
      @define-color sidebar_shade_color rgba(0, 0, 0, 0.36);

      @define-color secondary_sidebar_bg_color ${theme.base01};
      @define-color secondary_sidebar_fg_color ${theme.base06};
      @define-color secondary_sidebar_backdrop_color ${theme.base00};
      @define-color secondary_sidebar_shade_color rgba(0, 0, 0, 0.36);

      @define-color card_bg_color ${theme.base02};
      @define-color card_fg_color ${theme.base06};
      @define-color card_shade_color rgba(0, 0, 0, 0.36);

      @define-color dialog_bg_color ${theme.base01};
      @define-color dialog_fg_color ${theme.base06};

      @define-color popover_bg_color ${theme.base01};
      @define-color popover_fg_color ${theme.base06};
      @define-color popover_shade_color rgba(0, 0, 0, 0.25);

      @define-color thumbnail_bg_color ${theme.base01};
      @define-color thumbnail_fg_color ${theme.base06};

      @define-color shade_color rgba(0, 0, 0, 0.25);
      @define-color scrollbar_outline_color ${theme.base02};

      @define-color theme_bg_color ${theme.base00};
      @define-color theme_fg_color ${theme.base06};
      @define-color theme_base_color ${darken 30 theme.base00};
      @define-color theme_text_color ${theme.base06};
      @define-color theme_selected_bg_color ${theme.base0B};
      @define-color theme_selected_fg_color ${theme.base00};
      @define-color borders ${theme.base02};
    '';

    user = config.preferences.user.name;
  in {
    environment = {
      etc = {
        "xdg/gtk-3.0/settings.ini".text = gtksettings;
        "xdg/gtk-4.0/settings.ini".text = gtksettings;
      };

      variables = {
        GTK_THEME = theme-name;
        XCURSOR_THEME = cursor-theme-name;
        XCURSOR_SIZE = toString cursor-size;
      };
    };

    hjem.users.${user}.files = {
      ".config/gtk-3.0/gtk.css".text = palette;
      ".config/gtk-4.0/gtk.css".text = palette;
    };

    programs = {
      dconf = {
        enable = lib.mkDefault true;
        profiles = {
          user = {
            databases = [
              {
                lockAll = false;
                settings = {
                  "org/gnome/desktop/interface" = {
                    gtk-theme = theme-name;
                    icon-theme = icon-theme-name;
                    cursor-theme = cursor-theme-name;
                    cursor-size = lib.gvariant.mkInt32 cursor-size;
                    font-name = font-name;
                    monospace-font-name = monospace-font-name;
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
      cursor-theme-package

      pkgs.gtk3
      pkgs.gtk4
    ];
  };
}

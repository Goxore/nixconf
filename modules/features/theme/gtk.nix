{self, ...}: {
  modules.nixos.desktop = {
    pkgs,
    lib,
    config,
    ...
  }: let
    adw = self.lib.adwaita;

    theme-name = "adw-gtk3-dark";
    theme-package = pkgs.adw-gtk3;

    icon-theme-package = pkgs.gruvbox-plus-icons;
    icon-theme-name = "Gruvbox-Plus-Dark";

    cursor-theme-package = pkgs.vj.cursors;
    cursor-theme-name = self.lib.cursor.name;
    cursor-size = self.lib.cursor.size;

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
      @define-color accent_color ${adw.accentBg};
      @define-color accent_bg_color ${adw.accentBg};
      @define-color accent_fg_color ${adw.accentFg};

      @define-color destructive_color ${adw.destructiveBg};
      @define-color destructive_bg_color ${adw.destructiveBg};
      @define-color destructive_fg_color ${adw.destructiveFg};

      @define-color success_color ${adw.successBg};
      @define-color success_bg_color ${adw.successBg};
      @define-color success_fg_color ${adw.successFg};

      @define-color warning_color ${adw.warningBg};
      @define-color warning_bg_color ${adw.warningBg};
      @define-color warning_fg_color ${adw.warningFg};

      @define-color error_color ${adw.errorBg};
      @define-color error_bg_color ${adw.errorBg};
      @define-color error_fg_color ${adw.errorFg};

      @define-color window_bg_color ${adw.windowBg};
      @define-color window_fg_color ${adw.windowFg};

      @define-color view_bg_color ${adw.viewBg};
      @define-color view_fg_color ${adw.viewFg};

      @define-color headerbar_bg_color ${adw.headerbarBg};
      @define-color headerbar_fg_color ${adw.headerbarFg};
      @define-color headerbar_border_color ${adw.headerbarBorder};
      @define-color headerbar_backdrop_color ${adw.headerbarBackdrop};
      @define-color headerbar_shade_color ${adw.headerbarShade};

      @define-color sidebar_bg_color ${adw.sidebarBg};
      @define-color sidebar_fg_color ${adw.sidebarFg};
      @define-color sidebar_backdrop_color ${adw.sidebarBackdrop};
      @define-color sidebar_shade_color ${adw.sidebarShade};

      @define-color secondary_sidebar_bg_color ${adw.secondarySidebarBg};
      @define-color secondary_sidebar_fg_color ${adw.secondarySidebarFg};
      @define-color secondary_sidebar_backdrop_color ${adw.secondarySidebarBackdrop};
      @define-color secondary_sidebar_shade_color ${adw.secondarySidebarShade};

      @define-color card_bg_color ${adw.cardBg};
      @define-color card_fg_color ${adw.cardFg};
      @define-color card_shade_color ${adw.cardShade};

      @define-color dialog_bg_color ${adw.dialogBg};
      @define-color dialog_fg_color ${adw.dialogFg};

      @define-color popover_bg_color ${adw.popoverBg};
      @define-color popover_fg_color ${adw.popoverFg};
      @define-color popover_shade_color ${adw.popoverShade};

      @define-color thumbnail_bg_color ${adw.thumbnailBg};
      @define-color thumbnail_fg_color ${adw.thumbnailFg};

      @define-color shade_color ${adw.shade};
      @define-color scrollbar_outline_color ${adw.scrollbarOutline};

      @define-color theme_bg_color ${adw.windowBg};
      @define-color theme_fg_color ${adw.windowFg};
      @define-color theme_base_color ${adw.viewBg};
      @define-color theme_text_color ${adw.viewFg};
      @define-color theme_selected_bg_color ${adw.accentBg};
      @define-color theme_selected_fg_color ${adw.accentFg};
      @define-color borders ${adw.headerbarBorder};
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
                    inherit font-name;
                    inherit monospace-font-name;
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

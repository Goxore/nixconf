{
  pkgs,
  config,
  ...
}: let
  gruvboxPlus = import ./gruvbox-plus.nix {inherit pkgs;};
in let
  cssContent = with config.colorScheme.colors; ''
    @define-color accent_color #${base0D};
    @define-color accent_bg_color mix(#${base0D}, #${base00},0.3);
    @define-color accent_fg_color #${base00};
    @define-color destructive_color #${base0C};
    @define-color destructive_bg_color mix(#${base0C}, #${base00},0.3);
    @define-color destructive_fg_color #${base02};
    @define-color success_color #${base0B};
    @define-color success_bg_color mix(#${base0B}, black,0.6);
    @define-color success_fg_color #${base02};
    @define-color warning_color #${base0A};
    @define-color warning_bg_color mix(#${base0A}, black,0.6);
    @define-color warning_fg_color rgba(0, 0, 0, 0.8);
    @define-color error_color #${base08};
    @define-color error_bg_color mix(#${base0C}, #${base00},0.3);
    @define-color error_fg_color #${base02};
    @define-color window_bg_color #${base00};
    @define-color window_fg_color #${base04};
    @define-color view_bg_color #${base01};
    @define-color view_fg_color #${base04};
    @define-color headerbar_bg_color mix(#${base00},black,0.2);
    @define-color headerbar_fg_color #${base04};
    @define-color headerbar_border_color #${base02};
    @define-color headerbar_backdrop_color @window_bg_color;
    @define-color headerbar_shade_color rgba(0, 0, 0, 0.36);
    @define-color card_bg_color rgba(255, 255, 255, 0.08);
    @define-color card_fg_color #${base04};
    @define-color card_shade_color rgba(0, 0, 0, 0.36);
    @define-color dialog_bg_color #${base02};
    @define-color dialog_fg_color #${base04};
    @define-color popover_bg_color #${base02};
    @define-color popover_fg_color #${base04};
    @define-color shade_color rgba(0,0,0,0.36);
    @define-color scrollbar_outline_color rgba(0,0,0,0.5);
    @define-color blue_1 #${base0D};
    @define-color blue_2 #${base0D};
    @define-color blue_3 #${base0D};
    @define-color blue_4 #${base0D};
    @define-color blue_5 #${base0D};
    @define-color green_1 #${base0B};
    @define-color green_2 #${base0B};
    @define-color green_3 #${base0B};
    @define-color green_4 #${base0B};
    @define-color green_5 #${base0B};
    @define-color yellow_1 #${base0A};
    @define-color yellow_2 #${base0A};
    @define-color yellow_3 #${base0A};
    @define-color yellow_4 #${base0A};
    @define-color yellow_5 #${base0A};
    @define-color orange_1 #${base09};
    @define-color orange_2 #${base09};
    @define-color orange_3 #${base09};
    @define-color orange_4 #${base09};
    @define-color orange_5 #${base09};
    @define-color red_1 #${base08};
    @define-color red_2 #${base08};
    @define-color red_3 #${base08};
    @define-color red_4 #${base08};
    @define-color red_5 #${base08};
    @define-color purple_1 #${base0E};
    @define-color purple_2 #${base0E};
    @define-color purple_3 #${base0E};
    @define-color purple_4 #${base0E};
    @define-color purple_5 #${base0E};
    @define-color brown_1 #${base0F};
    @define-color brown_2 #${base0F};
    @define-color brown_3 #${base0F};
    @define-color brown_4 #${base0F};
    @define-color brown_5 #${base0F};
    @define-color light_1 #${base02};
    @define-color light_2 #f6f5f4;
    @define-color light_3 #deddda;
    @define-color light_4 #c0bfbc;
    @define-color light_5 #9a9996;
    @define-color dark_1 mix(#${base00},white,0.5);
    @define-color dark_2 mix(#${base00},white,0.2);
    @define-color dark_3 #${base00};
    @define-color dark_4 mix(#${base00},black,0.2);
    @define-color dark_5 mix(#${base00},black,0.4);
  '';
in {
  home.file = {
    ".local/share/icons/GruvboxPlus".source = "${gruvboxPlus}";
  };

  gtk.enable = true;

  gtk.theme.package = pkgs.adw-gtk3;
  gtk.theme.name = "adw-gtk3";

  gtk.cursorTheme.package = pkgs.bibata-cursors;
  gtk.cursorTheme.name = "Bibata-Modern-Ice";

  gtk.iconTheme.package = gruvboxPlus;
  gtk.iconTheme.name = "GruvboxPlus";

  xdg.configFile."gtk-4.0/gtk.css" = {
    text = cssContent;
  };

  xdg.configFile."gtk-3.0/gtk.css" = {
    text = cssContent;
  };
}

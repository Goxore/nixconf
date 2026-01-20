{
  inputs,
  self,
  lib,
  ...
}: let
  inherit
    (lib)
    getExe
    ;
  inherit
    (self)
    theme
    ;

  mkWhichKey = pkgs: menu:
    (self.wrapperModules.which-key.apply {
      inherit pkgs;
      settings = {
        inherit menu;

        font = "JetBrainsMono Nerd Font 12";
        background = theme.base00;
        color = theme.base06;
        border = theme.base0F;
        separator = " ➜ ";
        border_width = 2;
        corner_r = 15;
        padding = 15;
        rows_per_column = 5;
        column_padding = 25;

        anchor = "bottom-right";
        margin_right = 0;
        margin_bottom = 5;
        margin_left = 5;
        margin_top = 0;
      };
    }).wrapper;
in {
  flake.mkWhichKeyExe = pkgs: menu: getExe (mkWhichKey pkgs menu);

  flake.wrapperModules.which-key = inputs.wrappers.lib.wrapModule (
    {
      config,
      lib,
      ...
    }: let
      yamlFormat = config.pkgs.formats.yaml {};
    in {
      options = {
        settings = lib.mkOption {
          type = yamlFormat.type;
        };
      };

      config = {
        package = config.pkgs.wlr-which-key;

        args = [
          (toString (yamlFormat.generate "config.yaml" config.settings))
        ];
      };
    }
  );
}

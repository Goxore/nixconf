{
  flake.nixosModules.base = {
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) types mkOption;
  in {
    options.preferences = {
      keymap = mkOption {
        type = types.lazyAttrsOf (types.either types.attrs types.package);
        default = {};
        example = {
          # super + d and f keychord
          "SUPER + d" = {
            "f" = {
              exec = "firefox";
            };
          };
          # super + a and b and c keychord
          "SUPER + a" = {
            "b"."c" = {
              exec = "pcmanfm";
            };
          };
          # a
          "a" = {
            package = pkgs.firefox;
          };
          # a
          "a" = {
            exec = "pcmanfm";
          };
        };
      };
    };
  };
}

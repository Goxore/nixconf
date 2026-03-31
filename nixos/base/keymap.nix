{
  flake.nixosModules.base = {
    lib,
    pkgs,
    ...
  }: {
    options.preferences = {
      keymap = lib.mkOption {
        type = lib.types.lazyAttrsOf (lib.types.either lib.types.attrs lib.types.package);
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

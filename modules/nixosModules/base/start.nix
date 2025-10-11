{
  flake.nixosModules.base = {
    lib,
    ...
  }: let
    inherit
      (lib)
      types
      mkOption
      ;
  in {
    options.preferences = {
      autostart = mkOption {
        type = types.listOf (types.either types.str types.package);
        default = [];
      };
    };
  };
}

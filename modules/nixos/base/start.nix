{
  flake.nixosModules.base = {lib, ...}: {
    options.preferences = {
      autostart = lib.mkOption {
        type = lib.types.listOf (lib.types.either lib.types.str lib.types.package);
        default = [];
      };
    };
  };
}

{
  flake.nixosModules.base = {lib, ...}: {
    options.preferences = {
      user.name = lib.mkOption {
        type = lib.types.str;
        default = "yurii";
      };
    };
  };
}

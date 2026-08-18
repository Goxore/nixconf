{
  flake.wrappers.dynamic = {lib, ...}: {
    options.dynamicMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If true, resolve live paths instead of store paths for fast edits

        Both versions of the package may be installed simultaneously
      '';
    };
  };
}

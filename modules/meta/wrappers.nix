{
  inputs,
  options,
  config,
  lib,
  ...
}: let
  wlib = import "${inputs.wrapper-modules}/lib" {inherit lib;};

  deferred = lib.types.lazyAttrsOf lib.types.deferredModule;
in {
  options.wrappers = lib.mkOption {
    type = lib.types.lazyAttrsOf (wlib.types.subWrapperModuleWith {});
    default = {};
    description = ''
      Wrapped programs, keyed by the name they are built under. A name starting
      with "_" is a fragment other wrappers import rather than a program, so it
      is left out of packages, the same way the frame skips "_" files.
    '';
  };

  options.wrapperModules = lib.mkOption {
    type = deferred;
    readOnly = true;
  };

  config.wrapperModules =
    deferred.merge
    options.wrappers.loc
    options.wrappers.definitionsWithLocations;

  config.packages = pkgs:
    lib.genAttrs
    (lib.filter (name: !lib.hasPrefix "_" name)
      (lib.unique (builtins.concatMap
        (definition: builtins.attrNames definition.value)
        options.wrappers.definitionsWithLocations)))
    (name: config.wrappers.${name}.wrap {inherit pkgs;});
}

{
  lib,
  root,
  ...
}: let
  tagged = class: path: module: {
    _class = class;
    _file = "${toString root}#${path}";
    imports = [module];
  };
in {
  options = {
    lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
      description = "Helpers shared between modules in this flake";
    };

    modules = lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.deferredModule);
      default = {};
      apply = lib.mapAttrs (class: lib.mapAttrs (name: tagged class "modules.${class}.${name}"));
      description = ''
        Modules keyed by class, so a feature declares itself once and enrolls
        itself into whichever profiles it belongs to.
      '';
    };

    hosts = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = {};
      apply = lib.mapAttrs (name: tagged "nixos" "hosts.${name}");
      description = "Machines, lifted into nixosConfigurations by meta/hosts.nix";
    };
  };

  config.systems = ["x86_64-linux"];
}

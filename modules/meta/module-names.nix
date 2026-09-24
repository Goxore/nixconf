{
  config,
  lib,
  ...
}: let
  files = modules: builtins.concatMap (module: [module.file] ++ files module.imports) modules;

  profileOf = file: builtins.match ".*#modules\\.nixos\\.(.+)" file;

  imported = lib.unique (lib.concatMap
    (host: lib.concatLists (builtins.filter (name: name != null) (map profileOf (files host.graph))))
    (lib.attrValues config.nixosConfigurations));
in {
  checks = pkgs: let
    unused = lib.subtractLists imported (lib.attrNames config.modules.nixos);
  in {
    module-names =
      pkgs.runCommand "module-names-check" {}
      ''
        ${lib.optionalString (unused != []) ''
          echo "modules.nixos has names no host imports:"
          echo "  ${lib.concatStringsSep " " unused}"
          echo
          echo "Either a profile name is misspelled in a feature file, or no host"
          echo "imports that module yet."
          exit 1
        ''}
        touch $out
      '';
  };
}

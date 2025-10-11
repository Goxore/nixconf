{
  inputs,
  lib,
  ...
}: {
  flake.wrapperModules.kitty = inputs.wrappers.lib.mkWrapper (wlib: {config, ...}: let
    inherit (lib) mkOption types;
    inherit (lib.generators) mkKeyValueDefault;
    kittyKeyValueFormat = config.pkgs.formats.keyValue {
      listsAsDuplicateKeys = true;
      mkKeyValue = mkKeyValueDefault {} " ";
    };
    writeKittyConfig = cfg: kittyKeyValueFormat.generate "kitty.conf" cfg;
  in {
    options = {
      config = mkOption {
        type = kittyKeyValueFormat.type;
        default = {};
      };

      extraConfig = mkOption {
        type = types.str;
        default = "";
      };

      configFile = mkOption {
        type = wlib.types.file config.pkgs;
        default.path = toString (writeKittyConfig config.config) + config.extraConfig;
      };
    };

    config.package = config.pkgs.kitty;

    config.flags = {
      "-c" = config.configFile.path;
    };
  });
}

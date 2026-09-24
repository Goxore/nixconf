{
  inputs,
  config,
  lib,
  pkgsFor,
  build,
  ...
}: let
  inherit (config) nixpkgsOverlays;
in {
  nixosConfigurations =
    lib.mapAttrs
    (_: module:
      inputs.nixpkgs.lib.nixosSystem {
        modules = [
          module
          ({config, ...}: {
            nixpkgs.overlays =
              nixpkgsOverlays
              ++ [
                (_: _: {inherit (pkgsFor.${config.nixpkgs.hostPlatform.system}) vj;})
              ];
          })
          {system.configurationRevision = build.revision;}
        ];
      })
    config.hosts;
}

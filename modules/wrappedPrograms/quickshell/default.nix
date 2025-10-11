{
  inputs,
  ...
}: {
  perSystem = {pkgs, ...}: let
  in {
    packages.quickshellWrapped = inputs.wrappers.lib.makeWrapper {
      inherit pkgs;
      package = pkgs.quickshell;
      runtimeInputs = [
        pkgs.zoxide
      ];
      flags = {
        "-c" = ./.;
      };
    };
  };
}

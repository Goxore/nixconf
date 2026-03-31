{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages.quickshellWrapped = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.quickshell;
      runtimeInputs = [
        pkgs.zoxide
      ];
      flags = {
        "-c" = toString ./.;
      };
    };
  };
}

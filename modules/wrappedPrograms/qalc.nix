{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages.qalc = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.libqalculate;
      flags = {
      };
      args = [
        "-s"
        "autocalc"
        "-s"
        "decimal comma off"
      ];
    };
  };
}

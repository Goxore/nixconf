{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages.qalc = inputs.wrappers.lib.makeWrapper {
      inherit pkgs;
      package = pkgs.libqalculate;
      flags = {
        "-s" = "autocalc";
      };
    };
  };
}

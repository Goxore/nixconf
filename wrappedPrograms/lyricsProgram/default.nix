{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages.lyricsProgram = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.quickshell;
      flags = {
        "-c" = toString ./.;
      };
    };
  };
}

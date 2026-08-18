{
  flake.lib.rustShell = pkgs: runtimePkgs:
    pkgs.mkShell {
      packages =
        [
          pkgs.cargo
          pkgs.rustc
          pkgs.clippy
          pkgs.rustfmt
          pkgs.rust-analyzer
        ]
        ++ runtimePkgs;
    };
}

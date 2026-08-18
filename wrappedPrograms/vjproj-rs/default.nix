{
  inputs,
  lib,
  self,
  ...
}: {
  perSystem = {pkgs, ...}: let
    unwrapped = pkgs.rustPlatform.buildRustPackage {
      pname = "vjproj";
      version = "0.1.0";

      src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src ./tests];
      };

      cargoLock.lockFile = ./Cargo.lock;

      meta = {
        description = "Project workspace groups for mango";
        mainProgram = "vjproj";
      };
    };
  in {
    packages.vjproj = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = unwrapped;
      binName = "vjproj";
      runtimePkgs = [pkgs.mangowc];
    };

    devShells.vjproj = self.lib.rustShell pkgs [pkgs.mangowc];
  };
}

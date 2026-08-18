{
  inputs,
  lib,
  self,
  ...
}: {
  perSystem = {pkgs, ...}: let
    runtimePkgs = [pkgs.jujutsu pkgs.borgbackup pkgs.iproute2];

    unwrapped = pkgs.rustPlatform.buildRustPackage {
      pname = "vjtrees";
      version = "0.1.0";

      src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src ./tests];
      };

      cargoLock.lockFile = ./Cargo.lock;

      nativeBuildInputs = [pkgs.installShellFiles];

      nativeCheckInputs = [pkgs.jujutsu pkgs.borgbackup];

      preCheck = ''
        export HOME=$(mktemp -d)
      '';

      postInstall = ''
        installShellCompletion --cmd vjtrees \
          --bash <($out/bin/vjtrees completions bash) \
          --fish <($out/bin/vjtrees completions fish) \
          --zsh <($out/bin/vjtrees completions zsh)
      '';

      meta = {
        description = "Config-driven jj workspace manager";
        mainProgram = "vjtrees";
      };
    };
  in {
    packages.vjtrees = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = unwrapped;
      binName = "vjtrees";
      inherit runtimePkgs;
    };

    devShells.vjtrees = self.lib.rustShell pkgs runtimePkgs;
  };
}

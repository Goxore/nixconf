{
  inputs,
  lib,
  self,
  ...
}: let
  exe = pkgs: "${self.packages.${pkgs.stdenv.hostPlatform.system}.vjenv}/bin/vjenv";

  jjFixup = ''
    if [ -n "''${VJENV_IDENTITY:-}" ]; then
      __vjenv_jj="''${XDG_RUNTIME_DIR:-/tmp}/vjenv/''${VJENV_IDENTITY}.jj.toml"
      case ":''${JJ_CONFIG:-}:" in
        *":$__vjenv_jj:"*) ;;
        *) JJ_CONFIG="''${JJ_CONFIG:+$JJ_CONFIG:}$__vjenv_jj"; export JJ_CONFIG ;;
      esac
      unset __vjenv_jj
    fi
  '';

  envScript = pkgs: ''
    __vjenv_scope="''${VJENV_ROOT:-}"
    if [ -z "$__vjenv_scope" ]; then
      eval "$(${exe pkgs} env posix)"
    else
      case "$PWD" in
        "$__vjenv_scope" | "$__vjenv_scope"/*) ${jjFixup} ;;
        *) eval "$(${exe pkgs} env posix)" ;;
      esac
    fi
    unset __vjenv_scope
  '';
in {
  flake.lib.vjenv = {
    env = envScript;

    gated = pkgs: name: ''
      ${envScript pkgs}
      if [ -z "''${VJENV_IDENTITY:-}" ]; then
        echo "${name}: refusing to run — $PWD has no identity" >&2
        echo "       run: vjenv assign --identity <name>" >&2
        exit 1
      fi
    '';

  };

  perSystem = {pkgs, ...}: let
    template = pkgs.writeText "vjenv-identity.toml" ''
      [roots]
      standalone = ["~/NewVideos", "~/nixconf"]
      containers = ["~/Projects"]
      markers = [".vjenv-root", ".VJCROOT"]

      [identities.goxore]
      name = "Yurii"
      email = "yurii@goxore.com"
      ssh_key = "~/.ssh/primary"

      [identities.vimjoyer]
      name = "Vimjoyer"
      email = "vimjoyer@gmail.com"
      ssh_key = "~/.ssh/id_rsa_vimjoyer"
    '';

    unwrapped = pkgs.rustPlatform.buildRustPackage {
      pname = "vjenv";
      version = "0.1.0";

      src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src ./tests];
      };

      cargoLock.lockFile = ./Cargo.lock;

      nativeCheckInputs = [pkgs.fish pkgs.bash];

      meta = {
        description = "Directory-scoped identity and dev environments";
        mainProgram = "vjenv";
      };
    };
  in {
    packages.vjenv = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = unwrapped;
      binName = "vjenv";
      runtimePkgs = [pkgs.coreutils];
      env = {
        VJENV_TEMPLATE = "${template}";
        VJENV_SYSTEM = pkgs.stdenv.hostPlatform.system;
      };
    };

    devShells.vjenv = self.lib.rustShell pkgs [pkgs.coreutils pkgs.fish pkgs.bash];
  };
}

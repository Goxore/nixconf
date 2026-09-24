{
  inputs,
  self,
  ...
}: let
  exe = pkgs: "${pkgs.vj.vjenv}/bin/vjenv";

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
      eval "$(${exe pkgs} env posix --no-devshell)"
    else
      case "$PWD" in
        "$__vjenv_scope" | "$__vjenv_scope"/*) ${jjFixup} ;;
        *) eval "$(${exe pkgs} env posix --no-devshell)" ;;
      esac
    fi
    unset __vjenv_scope
  '';
in {
  lib.vjenv = {
    env = envScript;

    gatedDir = "/etc/vjenv/gated/bin";

    gated = pkgs: name: ''
      ${envScript pkgs}
      if [ -z "''${VJENV_IDENTITY:-}" ]; then
        echo "${name}: refusing to run — $PWD has no identity" >&2
        echo "       run: vjenv assign --identity <name>" >&2
        exit 1
      fi
    '';
  };

  modules.nixos.base = {pkgs, ...}: {
    environment.etc."vjenv/gated".source = pkgs.vj.vjenv-gated;

    persistence.data.directories = [
      ".config/vjenv"
      ".local/state/vjenv"
      ".local/share/vjenv"
    ];
  };

  packages = pkgs: let
    unwrapped = self.lib.rustCrate pkgs "vjenv" {
      nativeCheckInputs = [pkgs.fish pkgs.bash];

      meta.description = "Directory-scoped identity and dev environments";
    };
  in {
    vjenv = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = unwrapped;
      binName = "vjenv";
      runtimePkgs = [pkgs.coreutils];
      env = {
        VJENV_SYSTEM = pkgs.stdenv.hostPlatform.system;
        VJENV_FLAKE_LOADER = pkgs.vj.flake-loader;
      };
    };

    flake-loader = pkgs.writeText "flake-loader.nix" ''
      {
        dir,
        attr ? "default",
        system ? builtins.currentSystem,
      }: let
        outputs =
          (import ${inputs.flake-compat} {
            src.outPath = /. + dir;
            inherit system;
          }).outputs;
        path = builtins.filter builtins.isString (builtins.split "[.]" attr);
        lookup = prefix:
          builtins.foldl' (
            set: name:
              if builtins.isAttrs set && set ? ''${name}
              then set.''${name}
              else null
          )
          outputs (prefix ++ path);
        found = builtins.filter (value: value != null) (map lookup [
          ["devShells" system]
          ["packages" system]
          ["legacyPackages" system]
        ]);
      in {
        inherit outputs;
        shell =
          if found == []
          then builtins.foldl' (set: name: set.''${name}) outputs path
          else builtins.head found;
      }
    '';

    vjenv-gated = pkgs.runCommand "vjenv-gated" {} ''
      mkdir -p "$out/bin"
      for tool in ${pkgs.vj.gh}/bin/*; do
        ln -s "$tool" "$out/bin/$(basename "$tool")"
      done
    '';
  };

  devShells = pkgs: {
    vjenv = self.lib.rustShell pkgs [pkgs.coreutils pkgs.fish pkgs.bash];
  };
}

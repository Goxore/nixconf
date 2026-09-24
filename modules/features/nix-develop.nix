{lib, ...}: let
  mkNix = pkgs: realNix:
    pkgs.writeShellApplication {
      name = "nix";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        real=${realNix}
        loader=${pkgs.vj.flake-loader}

        sub=''${1-}
        case "$sub" in
          develop | print-dev-env) shift ;;
          *) exec "$real" "$@" ;;
        esac

        original=("$@")
        passthrough() {
          exec "$real" "$sub" "''${original[@]}"
        }

        ref=
        seen_ref=
        flags=()
        command=()
        while (($#)); do
          case "$1" in
            -c | --command)
              command=("$@")
              break
              ;;
            --build | --check | --configure | --install | --installcheck | --unpack | \
              --debugger | --impure | --no-update-lock-file | --no-write-lock-file | \
              --no-registries | --debug | --print-build-logs | -L | --quiet | --verbose | -v | \
              --offline | --refresh | --repair | --ignore-env | -i | --json)
              flags+=("$1")
              shift
              ;;
            --phase | --profile | --eval-store | --include | -I | --log-format | \
              --keep-env-var | -k | --unset-env-var | -u)
              (($# >= 2)) || passthrough
              flags+=("$1" "$2")
              shift 2
              ;;
            --option | --set-env-var | -s)
              (($# >= 3)) || passthrough
              flags+=("$1" "$2" "$3")
              shift 3
              ;;
            -*) passthrough ;;
            *)
              [[ -z $seen_ref ]] || passthrough
              seen_ref=1
              ref=$1
              shift
              ;;
          esac
        done

        ref=''${ref:-.}
        ref=''${ref#path:}
        [[ $ref == [./]* && $ref != *'?'* ]] || passthrough

        location=''${ref%%#*}
        attr=default
        if [[ $ref == *#* && -n ''${ref#*#} ]]; then
          attr=''${ref#*#}
        fi

        dir=$(realpath -e -- "$location") || passthrough
        while [[ ! -f $dir/flake.nix ]]; do
          [[ $dir != / ]] || passthrough
          dir=$(dirname -- "$dir")
        done

        exec "$real" "$sub" --impure --file "$loader" \
          --argstr dir "$dir" --argstr attr "$attr" shell \
          "''${flags[@]}" "''${command[@]}"
      '';
    };
in {
  packages = pkgs: {
    nix = mkNix pkgs (lib.getExe pkgs.nix);
  };

  modules.nixos.base = {pkgs, ...}: {
    environment.systemPackages = [(lib.hiPrio pkgs.vj.nix)];
  };

  checks = pkgs: let
    echoNix = pkgs.writeShellScript "echo-nix" ''printf '%s\n' "$@"'';
    wrapped = lib.getExe (mkNix pkgs echoNix);
    loader = pkgs.vj.flake-loader;
    expect = name: cwd: args: expected: ''
      actual=$(cd ${cwd} && ${wrapped} ${args})
      expected=$(printf '%s\n' ${expected})
      if [ "$actual" != "$expected" ]; then
        echo "${name}"
        diff <(echo "$expected") <(echo "$actual")
        exit 1
      fi
    '';
  in {
    nix-develop = pkgs.runCommand "nix-develop-check" {} ''
      mkdir -p proj/sub nested
      touch proj/flake.nix
      proj=$(realpath proj)

      ${expect "develop loads the current folder" "proj" "develop" ''
        develop --impure --file ${loader} --argstr dir "$proj" --argstr attr default shell
      ''}

      ${expect "a named shell, flags and a command survive" "proj/sub" "develop -L .#ci --profile p -c cargo build -v" ''
        develop --impure --file ${loader} --argstr dir "$proj" --argstr attr ci shell \
          -L --profile p -c cargo build -v
      ''}

      ${expect "print-dev-env takes a path: reference" "nested" "print-dev-env --json path:$proj" ''
        print-dev-env --impure --file ${loader} --argstr dir "$proj" --argstr attr default shell --json
      ''}

      ${expect "other subcommands pass through" "proj" "build ." "build ."}

      ${expect "remote flakes pass through" "proj" "develop github:o/r#x" "develop github:o/r#x"}

      ${expect "lock file flags pass through" "proj" "develop --override-input a b" ''
        develop --override-input a b
      ''}

      ${expect "a folder without a flake passes through" "nested" "develop" "develop"}

      touch $out
    '';
  };
}

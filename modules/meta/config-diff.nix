{self, ...}: {
  packages = pkgs: let
    aggregates = ./_config-snapshot.nix;

    fields = [
      "systemPackagesUnique"
      "etc"
      "persistence"
      "systemdServices"
      "systemdUser"
      "systemdTimers"
      "users"
      "userShells"
      "fonts"
      "defaultFonts"
      "consoleColors"
      "timeZone"
      "locale"
      "kernelModules"
      "kernelParams"
      "initrdModules"
      "initrdAvailable"
      "blacklisted"
      "hostName"
      "firewall"
      "stateVersion"
      "hjemFiles"
      "xdgPortal"
      "xdgPortals"
      "nixSettings"
    ];
  in {
    config-diff = pkgs.writeShellApplication {
      name = "config-diff";
      runtimeInputs = [pkgs.jq pkgs.diffutils pkgs.coreutils];
      text = ''
        usage() {
          cat >&2 <<'USAGE'
        config-diff REF_A REF_B [--hosts h1,h2] [--closure]

        Compares two evaluations of this flake and reports whether they differ
        semantically. REF_A and REF_B are flake refs, e.g.

          config-diff "path:/tmp/before" .
          config-diff "git+file:///path/to/nixconf?rev=<sha>" .

        --closure additionally builds both systems and compares the closure
        name sets, which catches changes the aggregates below do not cover.
        USAGE
          exit 2
        }

        [ $# -ge 2 ] || usage
        a="$1"; b="$2"; shift 2
        hosts=${pkgs.lib.escapeShellArg (builtins.concatStringsSep "," (builtins.attrNames self.nixosConfigurations))}
        closure=0
        while [ $# -gt 0 ]; do
          case "$1" in
            --hosts) [ $# -ge 2 ] && [ -n "$2" ] || usage; hosts="$2"; shift 2 ;;
            --closure) closure=1; shift ;;
            *) usage ;;
          esac
        done

        work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
        rc=0

        dump() {
          nix eval --json "$1#nixosConfigurations.$2.config" \
            --apply "$(cat ${aggregates})" 2>"$work/err" > "$3" || {
              echo "  ! failed to evaluate $2 from $1" >&2
              tail -3 "$work/err" >&2
              return 1
            }
        }

        for host in ''${hosts//,/ }; do
          echo "== $host"
          dump "$a" "$host" "$work/a.json" || { rc=1; continue; }
          dump "$b" "$host" "$work/b.json" || { rc=1; continue; }

          differing=0
          for f in ${builtins.concatStringsSep " " fields}; do
            if ! diff -q <(jq -cS ".$f" "$work/a.json") <(jq -cS ".$f" "$work/b.json") >/dev/null; then
              echo "  DIFF $f"
              diff <(jq -S ".$f" "$work/a.json") <(jq -S ".$f" "$work/b.json") \
                | sed 's/^/        /' | head -30 || true
              differing=$((differing + 1)); rc=1
            fi
          done
          if [ "$differing" -eq 0 ]; then echo "  all aggregates identical"; fi

          for side in a b; do
            total=$(jq -r '.systemPackages | length' "$work/$side.json")
            uniq=$(jq -r '.systemPackagesUnique | length' "$work/$side.json")
            [ "$total" -eq "$uniq" ] || echo "  note: $side has $((total - uniq)) duplicate systemPackages entries"
          done

          if [ "$closure" -eq 1 ]; then
            pa=$(nix build --no-link --print-out-paths "$a#nixosConfigurations.$host.config.system.build.toplevel")
            pb=$(nix build --no-link --print-out-paths "$b#nixosConfigurations.$host.config.system.build.toplevel")
            nix path-info -r "$pa" | sed 's|/nix/store/[a-z0-9]\{32\}-||' | sort > "$work/ca"
            nix path-info -r "$pb" | sed 's|/nix/store/[a-z0-9]\{32\}-||' | sort > "$work/cb"
            if diff -q "$work/ca" "$work/cb" >/dev/null; then
              echo "  closure: identical name set ($(wc -l < "$work/ca") paths)"
            else
              echo "  closure: name sets DIFFER"
              diff "$work/ca" "$work/cb" | sed 's/^/        /' | head -30 || true
              rc=1
            fi
            nix path-info -r "$pa" | sort > "$work/ha"
            nix path-info -r "$pb" | sort > "$work/hb"
            echo "  closure: $(comm -13 "$work/ha" "$work/hb" | wc -l) of $(wc -l < "$work/hb") paths rebuilt"
          fi
        done

        exit $rc
      '';
    };
  };
}

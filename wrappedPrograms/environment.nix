{
  lib,
  inputs,
  self,
  ...
}: {
  flake.wrappers.environment = {pkgs, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";

    packageOf = entry: entry.data or entry;

    runtimeTools = [
      pkgs.nil
      pkgs.nixd
      pkgs.statix
      pkgs.alejandra
      pkgs.manix
      pkgs.nix-inspect
      pkgs.file
      pkgs.unzip
      pkgs.zip
      pkgs.p7zip
      pkgs.wget
      pkgs.killall
      pkgs.sshfs
      pkgs.fzf
      pkgs.htop
      selfpkgs.btop
      pkgs.eza
      pkgs.fd
      pkgs.zoxide
      pkgs.dust
      pkgs.ripgrep
      pkgs.fastfetch
      pkgs.tree-sitter
      pkgs.imagemagick
      pkgs.imv
      pkgs.quickshell
      pkgs.ffmpeg-full
      pkgs.yt-dlp
      pkgs.lazygit
      pkgs.just
      pkgs.mprocs
      pkgs.devenv
      {
        data = pkgs.secretspec;
        prefix = true;
      }
      pkgs.bitwarden-cli
      selfpkgs.nh
      selfpkgs.neovimDynamic
      selfpkgs.qalc
      selfpkgs.lf
      selfpkgs.git
      selfpkgs.jujutsu
      selfpkgs.jjui
      selfpkgs.nix-check-bin
      selfpkgs.jprocsall
      selfpkgs.jprocs
      selfpkgs.dev
      selfpkgs.vjenv
      selfpkgs.vjtrees
      selfpkgs.claude-per
      selfpkgs.claude-fish
      selfpkgs.codex
    ];
  in {
    imports = [self.wrapperModules.fish];
    binName = "fish";
    runtimePkgs = runtimeTools;

    prefixVar = [
      [
        "fish_complete_path"
        ":"
        (lib.makeSearchPath "share/fish/vendor_completions.d" (map packageOf runtimeTools))
      ]
    ];

    env = {
      EDITOR = lib.getExe selfpkgs.neovimDynamic;
      __NIXOS_SET_ENVIRONMENT_DONE = "1";

      FZF_DEFAULT_OPTS = with self.theme;
        lib.concatStringsSep " " [
          "--color=bg+:${base01},bg:${base00},spinner:${base0C},hl:${base0D}"
          "--color=fg:${base04},header:${base0D},info:${base0A},pointer:${base0C}"
          "--color=marker:${base0C},fg+:${base06},prompt:${base0A},hl+:${base0D}"
          "--color=border:${base02},gutter:${base00},query:${base06}"
        ];
    };
  };

  flake.wrappers.terminal = {pkgs, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [self.wrapperModules.kitty];
    shell = lib.getExe selfpkgs.environment;
  };

  perSystem = {pkgs, ...}: {
    packages.jprocs = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.mprocs;
      binName = "jprocs";
      addFlag = ["--just"];
      flags = {
        "--log-dir" = "/tmp/jprocs.log";
      };
    };

    packages.jprocsall = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.mprocs;
      binName = "jprocsall";
      addFlag = ["--just"];
      flags = {
        "--on-init" = "{c: restart-all}";
        "--log-dir" = "/tmp/jprocsall.log";
      };
    };

    packages.screenshot = pkgs.writeShellApplication {
      name = "screenshot";
      text = ''${pkgs.grim}/bin/grim -l 0 - | ${pkgs.wl-clipboard}/bin/wl-copy '';
    };

    packages.screenshotFull = pkgs.writeShellApplication {
      name = "screenshotFull";
      text = ''${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp -w 0)" - | ${pkgs.wl-clipboard}/bin/wl-copy'';
    };

    packages.pipeSwappy = pkgs.writeShellApplication {
      name = "pipeSwappy";
      text = ''${pkgs.wl-clipboard}/bin/wl-paste | ${pkgs.swappy}/bin/swappy -f -'';
    };

    packages.vol = pkgs.writeShellApplication {
      name = "vol";

      runtimeInputs = [pkgs.playerctl pkgs.gawk];

      text = ''
        set -euo pipefail

        f="''${XDG_CACHE_HOME:-$HOME/.cache}/vol"
        v=$(cat "$f" 2>/dev/null || echo 0.5)
        s=0.1

        case "''${1:-}" in
          up)   v=$(awk -v v="$v" -v s="$s" 'BEGIN{print v+s}') ;;
          down) v=$(awk -v v="$v" -v s="$s" 'BEGIN{print v-s}') ;;
          set)  v="''${2:-$v}" ;;
          *) exit 1 ;;
        esac

        v=$(awk -v v="$v" 'BEGIN{if(v<0)v=0;if(v>1)v=1;print v}')

        playerctl volume "$v"
        mkdir -p "$(dirname "$f")"
        echo "$v" > "$f"
      '';
    };

    packages.volYtMusic = pkgs.writeShellApplication {
      name = "vol-ytmusic";

      runtimeInputs = [pkgs.playerctl pkgs.gawk pkgs.jq];

      text = ''
        set -euo pipefail

        f="''${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/vjshell-ytmusic-volume.json"
        v=$(jq -r '.volume // empty' "$f" 2>/dev/null || echo "")
        [ -n "$v" ] || v=0.5
        s=0.1

        case "''${1:-}" in
          up)   v=$(awk -v v="$v" -v s="$s" 'BEGIN{print v+s}') ;;
          down) v=$(awk -v v="$v" -v s="$s" 'BEGIN{print v-s}') ;;
          set)  v="''${2:-$v}" ;;
          *) exit 1 ;;
        esac

        v=$(awk -v v="$v" 'BEGIN{if(v<0)v=0;if(v>1)v=1;print v}')

        mkdir -p "$(dirname "$f")"
        printf '{"volume": %s}\n' "$v" > "$f"

        playerctl -p YoutubeMusic volume "$v" 2>/dev/null || true
      '';
    };

    packages.nix-check-bin = pkgs.writeShellScriptBin "nix-check-bin" ''
      $EDITOR "$(nix build "$1" --no-link --print-out-paths)/bin"
    '';

    packages.dev = pkgs.writeTextFile {
      name = "dev";
      executable = true;
      destination = "/bin/dev";
      text = let
        vjenv = "${self.packages.${pkgs.stdenv.hostPlatform.system}.vjenv}/bin/vjenv";
      in ''
        #!${lib.getExe pkgs.fish}
        if set -q argv[1]
            set -l override (${vjenv} use --shell fish $argv[1]); or exit 1
            echo $override | source
        end
        ${vjenv} env fish --no-devshell | source
        set -gx NIXPKGS_ALLOW_UNFREE 1
        nix develop --impure -c $SHELL
      '';
    };
  };
}

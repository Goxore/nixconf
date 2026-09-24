{
  wrapperModules,
  lib,
  inputs,
  self,
  ...
}: let
  stepVolume = ''
    s=0.1
    case "''${1:-}" in
      up)   v=$(awk -v v="$v" -v s="$s" 'BEGIN{print v+s}') ;;
      down) v=$(awk -v v="$v" -v s="$s" 'BEGIN{print v-s}') ;;
      set)  v="''${2:-$v}" ;;
      *) exit 1 ;;
    esac
    v=$(awk -v v="$v" 'BEGIN{if(v<0)v=0;if(v>1)v=1;print v}')
  '';
in {
  wrappers.environment = {pkgs, ...}: let
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
      pkgs.vj.btop
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
      pkgs.tack
      {
        data = pkgs.secretspec;
        prefix = true;
      }
      pkgs.bitwarden-cli
      pkgs.vj.nh
      pkgs.vj.neovimDynamic
      pkgs.vj.qalc
      pkgs.vj.lf
      pkgs.vj.git
      pkgs.vj.jujutsu
      pkgs.vj.jjui
      pkgs.vj.nix-check-bin
      pkgs.vj.jprocsall
      pkgs.vj.jprocs
      pkgs.vj.dev
      pkgs.vj.tmux
      pkgs.vj.vjenv
      pkgs.vj.claude-per
      pkgs.vj.claude-fish
      pkgs.vj.codex
      pkgs.vj.opencode
    ];
  in {
    imports = [wrapperModules.fish];
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
      EDITOR = lib.getExe pkgs.vj.neovimDynamic;
      __NIXOS_SET_ENVIRONMENT_DONE = "1";

      FZF_DEFAULT_OPTS = lib.concatStringsSep " " [
        "--color=bg+:${self.lib.theme.base01},bg:${self.lib.theme.base00},spinner:${self.lib.theme.base0C},hl:${self.lib.theme.base0D}"
        "--color=fg:${self.lib.theme.base04},header:${self.lib.theme.base0D},info:${self.lib.theme.base0A},pointer:${self.lib.theme.base0C}"
        "--color=marker:${self.lib.theme.base0C},fg+:${self.lib.theme.base06},prompt:${self.lib.theme.base0A},hl+:${self.lib.theme.base0D}"
        "--color=border:${self.lib.theme.base02},gutter:${self.lib.theme.base00},query:${self.lib.theme.base06}"
      ];
    };
  };

  wrappers.terminal = {pkgs, ...}: {
    imports = [wrapperModules.kitty];
    shell = lib.getExe pkgs.vj.environment;
  };

  packages = pkgs: {
    jprocs = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.mprocs;
      binName = "jprocs";
      addFlag = ["--just"];
      flags = {
        "--log-dir" = "/tmp/jprocs.log";
      };
    };

    jprocsall = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.mprocs;
      binName = "jprocsall";
      addFlag = ["--just"];
      flags = {
        "--on-init" = "{c: restart-all}";
        "--log-dir" = "/tmp/jprocsall.log";
      };
    };

    screenshot = pkgs.writeShellApplication {
      name = "screenshot";
      text = ''${pkgs.grim}/bin/grim -l 0 - | ${pkgs.wl-clipboard}/bin/wl-copy '';
    };

    screenshotRegion = pkgs.writeShellApplication {
      name = "screenshotRegion";
      text = ''${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp -w 0)" - | ${pkgs.wl-clipboard}/bin/wl-copy'';
    };

    pipeSwappy = pkgs.writeShellApplication {
      name = "pipeSwappy";
      text = ''${pkgs.wl-clipboard}/bin/wl-paste | ${pkgs.swappy}/bin/swappy -f -'';
    };

    vol = pkgs.writeShellApplication {
      name = "vol";

      runtimeInputs = [pkgs.playerctl pkgs.gawk];

      text = ''
        f="''${XDG_CACHE_HOME:-$HOME/.cache}/vol"
        v=$(cat "$f" 2>/dev/null || echo 0.5)
        ${stepVolume}

        playerctl volume "$v"
        mkdir -p "$(dirname "$f")"
        echo "$v" > "$f"
      '';
    };

    volYtMusic = pkgs.writeShellApplication {
      name = "vol-ytmusic";

      runtimeInputs = [pkgs.playerctl pkgs.gawk pkgs.jq];

      text = ''
        f="''${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/vjshell-ytmusic-volume.json"
        v=$(jq -r '.volume // empty' "$f" 2>/dev/null || echo "")
        [ -n "$v" ] || v=0.5
        ${stepVolume}

        mkdir -p "$(dirname "$f")"
        printf '{"volume": %s}\n' "$v" > "$f"

        playerctl -p YoutubeMusic volume "$v" 2>/dev/null || true
      '';
    };

    nix-check-bin = pkgs.writeShellScriptBin "nix-check-bin" ''
      $EDITOR "$(nix build "$1" --no-link --print-out-paths)/bin"
    '';

    dev = pkgs.writeTextFile {
      name = "dev";
      executable = true;
      destination = "/bin/dev";
      text = let
        vjenv = "${pkgs.vj.vjenv}/bin/vjenv";
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

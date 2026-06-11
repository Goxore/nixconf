{
  lib,
  inputs,
  self,
  ...
}: {
  flake.wrappers.environment = {pkgs, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [self.wrapperModules.fish];
    binName = "fish";
    runtimePkgs = [
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
      pkgs.btop
      pkgs.eza
      pkgs.fd
      pkgs.zoxide
      pkgs.dust
      pkgs.ripgrep
      pkgs.fastfetch
      pkgs.tree-sitter
      pkgs.imagemagick
      pkgs.imv
      pkgs.ffmpeg-full
      pkgs.yt-dlp
      pkgs.lazygit
      pkgs.just
      pkgs.mprocs
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
    ];
    env.EDITOR = lib.getExe selfpkgs.neovimDynamic;
  };

  flake.wrappers.desktop = {pkgs, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [self.wrapperModules.niri];
    terminal = lib.getExe selfpkgs.terminal;
    env = {
      EDITOR = lib.getExe selfpkgs.neovim;
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

    packages.nix-check-bin = pkgs.writeShellScriptBin "nix-check-bin" ''
      $EDITOR "$(nix build "$1" --no-link --print-out-paths)/bin"
    '';
  };
}

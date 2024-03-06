{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.myHomeManager;

  pimg = pkgs.writeShellScriptBin "pimg" ''
    output="out.png"
    [ ! -z "$1" ] && output="$1.png"
    # xclip -se c -t image/png -o > "$output"
    ${pkgs.wl-clipboard}/bin/wl-paste > "$output"
  '';

in {
  home.file = {
    ".local/share/zsh/zsh-autosuggestions".source = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
    ".local/share/zsh/zsh-fast-syntax-highlighting".source = "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions";
    ".local/share/zsh/nix-zsh-completions".source = "${pkgs.nix-zsh-completions}/share/zsh/plugins/nix";
    ".local/share/zsh/zsh-vi-mode".source = "${pkgs.zsh-vi-mode}/share/zsh-vi-mode";
  };

  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    shellAliases = {
      ls = "${pkgs.eza}/bin/eza --icons -a --group-directories-first";
      tree = "${pkgs.eza}/bin/eza --color=auto --tree";
      cal = "cal -m";
      grep = "grep --color=auto";
      q = "exit";
      ":q" = "exit";
    };
  };

  programs.zsh.initExtra = ''
    # EXTRACT FUNCTION (needs more nix)

    hst() {
        history 0 | cut -c 8- | uniq | ${pkgs.fzf}/bin/fzf | ${pkgs.wl-clipboard}/bin/wl-copy
    }

    proj() {
      dir="$(cat ~/.local/share/direnv/allow/* | uniq | xargs dirname | ${pkgs.fzf}/bin/fzf --height 9)"
      cd "$dir"
    }
    bindkey -s '\eOP' 'proj\n'

    plf() {
      proj
      lf
    }

    detach() {
      prog=$1
      shift
      nohup setsid $prog $@ > /dev/null 2>&1
    }

    ex () {
      if [ -f $1 ] ; then
        case $1 in
          *.tar.bz2)   tar xjf $1   ;;
          *.tar.gz)    tar xzf $1   ;;
          *.bz2)       bunzip2 $1   ;;
          *.rar)       ${pkgs.unrar}/bin/unrar x $1   ;;
          *.gz)        gunzip $1    ;;
          *.tar)       tar xf $1    ;;
          *.tbz2)      tar xjf $1   ;;
          *.tgz)       tar xzf $1   ;;
          *.zip)       unzip $1     ;;
          *.Z)         uncompress $1;;
          *.7z)        7z x $1      ;;
          *.deb)       ar x $1      ;;
          *.tar.xz)    tar xf $1    ;;
          *.tar.zst)   tar xf $1    ;;
          *)           echo "'$1' cannot be extracted via ex()" ;;
        esac
      else
        echo "'$1' is not a valid file"
      fi
    }

    # PROMPT
    autoload -U colors && colors

    PROMPTBASE="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}$%b "

    checkExtraDev()
    {
        [ -z ''${extra_dev_shell} ] && return

        addspace=""
        [ ! -z ''${extra_packages} ] && addspace=" "
        echo "$extra_dev_shell$addspace"
    }

    updateps1()
    {
    PS1="
    $PROMPTBASE"

    [ ! -z ''${extra_dev_shell} ] || [ ! -z ''${extra_packages} ] && \
    PS1="
    %B$fg[red][$fg[green]$(checkExtraDev)$fg[blue]$extra_packages$fg[red]]$fg[blue] 
    $PROMPTBASE"

    }
    updateps1

    # PLUGINS (whatever)
    [ -f "$HOME/.local/share/zsh/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ] && \
    source "$HOME/.local/share/zsh/zsh-vi-mode/zsh-vi-mode.plugin.zsh"

    [ -f "$HOME/.local/share/zsh/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ] && \
    source "$HOME/.local/share/zsh/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"

    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#${config.colorScheme.colors.base03}"
    bindkey '^ ' autosuggest-accept

    [ -f "$HOME/.local/share/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
    source "$HOME/.local/share/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"

    [ -f "$HOME/.local/share/zsh/nix-zsh-completions/nix.plugin.zsh" ] && \
    source "$HOME/.local/share/zsh/nix-zsh-completions/nix.plugin.zsh"

    if [[ -n $CUSTOMZSHTOSOURCE ]]; then
      source "$CUSTOMZSHTOSOURCE"
    fi

    chpwdf() {
        if env | grep -q direnv; then
            extra_dev_shell="direnv"
        else
            if [[ "$extra_dev_shell" = "direnv" ]]; then
                unset extra_dev_shell
            fi
        fi

        updateps1
    }

    chpwd_functions+=(chpwdf)
  '';

  programs.zsh.envExtra = ''
    export EDITOR="nvim"
    export TERMINAL="alacritty"
    export TERM="alacritty"
    export BROWSER="firefox"
    export VIDEO="mpv"
    export IMAGE="imv"
    export OPENER="xdg-open"
    export SCRIPTS="$HOME/scripts"
    export LAUNCHER="rofi -dmenu"
    export FZF_DEFAULT_OPTS="--color=16"

    # Less colors
    export LESS_TERMCAP_mb=$'\e[1;32m'
    export LESS_TERMCAP_md=$'\e[1;32m'
    export LESS_TERMCAP_me=$'\e[0m'
    export LESS_TERMCAP_se=$'\e[0m'
    export LESS_TERMCAP_so=$'\e[01;33m'
    export LESS_TERMCAP_ue=$'\e[0m'
    export LESS_TERMCAP_us=$'\e[1;4;31m'
    export vimcolorscheme="gruvbox"

    # direnv
    export DIRENV_LOG_FORMAT=""
  '';

  home.packages = [
    pimg

    (pkgs.writeShellScriptBin "mk" ''
      mkdir -p $( dirname "$1") && touch "$1"
    '')
  ];
}

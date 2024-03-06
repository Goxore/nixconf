{
  pkgs,
  inputs,
  config,
  ...
}: let

  # ========================= Discontinued ========================= #

  rev = inputs.nixpkgs.rev;
  os = pkgs.writeShellScriptBin "os" ''

    RED='\033[1;31m'
    GREEN='\033[1;32m'
    BLUE='\033[1;34m'
    NC='\033[0m'

    rev() {
        echo "${rev}"
    }

    finfo() {
      printf "''${GREEN}Name: ''${NC}$CONFNAME\n"
      printf "''${GREEN}Path: ''${NC}$CONFPATH\n"
      printf "''${GREEN}Nixpkgs: ''${NC}${rev}\n"
    }


    fgetsudo() {
    if [[ $EUID -ne 0 ]];
    then
        exec sudo "$0" "$args"
        exit
    fi
    }

    fsetup() {
        fgetsudo

        if [ ! -d "/etc/myos/" ]; then
          mkdir /etc/myos/
          printf "''${GREEN}Created directory /etc/myos/\n"
        fi

        if [ ! -f "/etc/myos/conf" ]; then
          touch /etc/myos/conf
          printf "''${GREEN}Created file /etc/myos/conf\n"
        fi

        if [ -s "/etc/myos/conf" ]; then
          CONFNAME=$(head -n 1 "/etc/myos/conf")
        else
          read -p "Enter conf name: " CONFNAME
          echo "$CONFNAME" > /etc/myos/conf
        fi

        if [ $(wc -l < "/etc/myos/conf") -ge 2 ]; then
          CONFPATH=$(sed -n '2p' "/etc/myos/conf")
        else
          read -p "Enter path: " -i "$(pwd)" CONFPATH
          echo "$CONFPATH" >> /etc/myos/conf
        fi

        finfo
    }

    fremoveconf() {
        rm /etc/myos/conf
    }


    if [[ -f "/etc/myos/conf" ]]; then
        CONFNAME=$(head -n 1 "/etc/myos/conf")
        if [[ -n "$CONFNAME" ]]; then
            CONFPATH=$(sed -n '2p' "/etc/myos/conf")
            if [[ -n "$CONFPATH" ]]; then
                # something was there
                true
            else
                fsetup
            fi
        else
            fsetup
        fi
    else
        fsetup
    fi

    frebuild() {
        finfo
        printf "''${BLUE}Running command: ''${NC}nixos-rebuild switch --flake $CONFPATH#$CONFNAME\n\n"
        nixos-rebuild switch --flake $CONFPATH#$CONFNAME
    }

    ftest() {
        finfo
        printf "''${BLUE}Running command: ''${NC}nixos-rebuild test --fast --flake $CONFPATH#$CONFNAME\n\n"
        nixos-rebuild test --fast --flake $CONFPATH#$CONFNAME
    }

    fupdate() {
        finfo
        cd "$CONFPATH"
        printf "''${BLUE}Running command: ''${NC}nix flake update\n\n"
        nix flake update
    }

    fclean() {
        printf "''${BLUE}Collecting garbage: ''${NC}\n\n"
        nix store optimise --verbose
        nix store gc --verbose
    }

    args="$@"

    case "$1" in
        rev)
            shift
            rev
            ;;
        m|metadata)
            shift
            finfo
            ;;
        setup)
            shift
            fremoveconf
            fsetup
            ;;
        r|rebuild)
            shift
            fgetsudo
            frebuild
            ;;
        t|test)
            shift
            fgetsudo
            ftest
            ;;
        u|update)
            shift
            fupdate
            ;;
        c|clean)
            shift
            fgetsudo
            fclean
            ;;
        *)
            printf "''${RED}Unknown command: $@''${NC}\n"
            ;;
    esac
    exit 0
  '';
in {
  environment.systemPackages = [
    os
  ];
}

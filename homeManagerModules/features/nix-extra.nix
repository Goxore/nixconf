{
  pkgs,
  inputs,
  ...
}: let
  nxs = pkgs.writeShellScriptBin "nxs" ''
    export NIXPKGS_ALLOW_UNFREE=1
    fmt_packages=""
    extra_packages="$extra_packages"

    for arg in "$@"; do
        extra_packages="$extra_packages $arg"

        if [[ $arg != *:* && $arg != *#* ]]; then
          arg="github:nixos/nixpkgs/${inputs.nixpkgs.rev}#$arg"
        fi

        fmt_packages="$fmt_packages $arg"
    done

    extra_packages=$(echo "$extra_packages" | sed 's/^ //')

    env extra_packages="$extra_packages" nix shell --impure $fmt_packages
  '';

  # devshellname="$devshellname $(nix flake "$1" metadata --json | ${pkgs.jq}/bin/jq '.description')"
  # devshellname=$(echo "$devshellname" | sed 's/^ //')
  nxd = pkgs.writeShellScriptBin "nxd" ''
    export NIXPKGS_ALLOW_UNFREE=1
    env extra_dev_shell="$devshellname" nix develop "$@" --impure --accept-flake-config -c $SHELL
  '';

  nxr = pkgs.writeShellScriptBin "nxr" ''
    export NIXPKGS_ALLOW_UNFREE=1
    arg="$1"
    shift
    if [[ $arg != *:* && $arg != *#* ]]; then
      arg="github:nixos/nixpkgs/${inputs.nixpkgs.rev}#$arg"
    fi
    nix run --impure "$arg" "$@"
  '';
in {
  imports = [
    inputs.nix-index-database.hmModules.nix-index
  ];

  home.packages = with pkgs; [
    nxd
    nxs
    nxr
    nil
    alejandra
  ];
}

{
  pkgs,
  inputs,
  ...
}: let
  nxs = pkgs.writeShellScriptBin "nxs" ''
    fmt_packages=""
    extra_packages="$extra_packages"

    for arg in "$@"; do
        extra_packages="$extra_packages $arg"

        if [[ $arg != *:* ]]; then
          arg="github:nixos/nixpkgs/${inputs.nixpkgs.rev}#$arg"
        fi

        fmt_packages="$fmt_packages $arg"
    done

    extra_packages=$(echo "$extra_packages" | sed 's/^ //')

    env extra_packages="$extra_packages" nix shell --impure $fmt_packages
  '';

  nxd = pkgs.writeShellScriptBin "nxd" ''
    devshellname="$devshellname $(nix flake metadata --json | ${pkgs.jq}/bin/jq '.description')"
    devshellname=$(echo "$devshellname" | sed 's/^ //')
    env extra_dev_shell="$devshellname" nix develop --impure -c zsh
  '';

  # nld = pkgs.writeShellScriptBin "nld" ''
  #   export NIX_LD=${pkgs.lib.fileContents pkgs.stdenv.cc}/nix-support/dynamic-linker";
  #   export NIX_LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath ldPackages}";
  # '';

  nxr = pkgs.writeShellScriptBin "nxr" ''
    nix run --impure github:nixos/nixpkgs/${inputs.nixpkgs.rev}#$@
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

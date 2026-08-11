{
  flake.wrappers.quickshellWrapped = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.quickshell;
    runtimePkgs = [pkgs.zoxide];
    flags."-p" = toString ./.;
  };
}

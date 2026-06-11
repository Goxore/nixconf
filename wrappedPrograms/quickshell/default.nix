{
  flake.wrappers.quickshellWrapped = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.quickshell;
    runtimeInputs = [pkgs.zoxide];
    flags."-c" = toString ./.;
  };
}

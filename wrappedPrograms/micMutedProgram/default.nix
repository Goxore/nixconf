{
  flake.wrappers.micMutedProgram = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.quickshell;
    flags."-p" = toString ./.;
  };
}

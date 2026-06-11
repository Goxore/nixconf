{
  flake.wrappers.lyricsProgram = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.quickshell;
    flags."-c" = toString ./.;
  };
}

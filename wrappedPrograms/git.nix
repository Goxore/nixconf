{self, ...}: {
  flake.wrappers.git = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.git;

    runShell = [(self.lib.vjenv.env pkgs)];
  };
}

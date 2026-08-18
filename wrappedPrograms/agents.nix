{
  self,
  lib,
  ...
}: {
  flake.wrappers.gh = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.gh;
    runShell = [(self.lib.vjenv.gated pkgs "gh")];
  };

  flake.wrappers.codex = {
    wlib,
    pkgs,
    ...
  }: let
    vjprojExe = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.vjproj;

    turnDone = pkgs.writeShellScript "vjproj-codex-notify" ''
      exec ${vjprojExe} agent report --activity idle
    '';
  in {
    imports = [wlib.modules.default];
    package = pkgs.codex;
    binName = "codex";
    env.__NIXOS_SET_ENVIRONMENT_DONE = "1";
    runShell = [
      (self.lib.vjenv.tool pkgs "codex")
      ''
        export VJAGENT_PID=$$
        export VJAGENT_KIND=codex
        export VJAGENT_REPORTING=coarse
        ${vjprojExe} agent report --activity idle || true
      ''
    ];

    flags."-c" = ''notify=["${turnDone}"]'';
  };
}

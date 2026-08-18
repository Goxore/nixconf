{
  self,
  lib,
  ...
}: {
  flake.lib.agentHome = pkgs: {
    var,
    dir,
    instructions,
  }: let
    home = "$HOME/.local/share/${dir}";
    shared = "$HOME/.config/vjenv/AGENTS.md";
  in ''
    export ${var}="${home}"
    ${pkgs.coreutils}/bin/mkdir -p "${home}"
    if [ -f "${shared}" ]; then
      ${pkgs.coreutils}/bin/cp -f "${shared}" "${home}/${instructions}"
    fi
  '';

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
      (self.lib.agentHome pkgs {
        var = "CODEX_HOME";
        dir = "codex";
        instructions = "AGENTS.md";
      })
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

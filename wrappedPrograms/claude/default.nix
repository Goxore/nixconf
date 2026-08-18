{
  self,
  lib,
  ...
}: let
  mkClaude = flavour: {
    wlib,
    pkgs,
    ...
  }: let
    vjprojExe = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.vjproj;

    report = activity: {
      hooks = [
        {
          type = "command";
          command = "${vjprojExe} agent report --activity ${activity}";
        }
      ];
    };
  in {
    imports = [wlib.wrapperModules.claude-code];

    binName = flavour;
    env.__NIXOS_SET_ENVIRONMENT_DONE = "1";
    runShell = [
      (self.lib.agentHome pkgs {
        var = "CLAUDE_CONFIG_DIR";
        dir = flavour;
        instructions = "CLAUDE.md";
      })
      ''
        export VJAGENT_PID=$$
        export VJAGENT_KIND=${flavour}
        export VJAGENT_REPORTING=precise
        ${vjprojExe} agent report --activity idle || true
      ''
    ];

    settings.statusLine = {
      type = "command";
      command = "${lib.getExe pkgs.bun} run ${./statusline.ts}";
    };

    settings.hooks = {
      UserPromptSubmit = [(report "working")];
      Notification = [(report "blocked")];
      Stop = [(report "idle")];
      SessionEnd = [
        {
          hooks = [
            {
              type = "command";
              command = "${vjprojExe} agent end";
            }
          ];
        }
      ];
    };
  };
in {
  flake.wrappers.claude-per = mkClaude "claude-per";
  flake.wrappers.claude-fish = mkClaude "claude-fish";
}

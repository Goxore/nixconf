{
  self,
  lib,
  ...
}: {
  flake.wrappers.claude = {
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

    binName = "claude";
    env.__NIXOS_SET_ENVIRONMENT_DONE = "1";
    runShell = [
      (self.lib.vjenv.tool pkgs "claude")
      ''
        export VJAGENT_PID=$$
        export VJAGENT_KIND=claude
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
}

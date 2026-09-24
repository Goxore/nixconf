{
  self,
  lib,
  ...
}: let
  agentTmux = pkgs: ''
    if [ -z "''${TMUX:-}" ] && [ -t 0 ] && [ -t 1 ]; then
      __vjagent_self="''${BASH_SOURCE[0]}"
      case "$__vjagent_self" in
        /*) ;;
        *) __vjagent_self="$PWD/$__vjagent_self" ;;
      esac
      __vjagent_carry=""
      if [ -n "''${VJAGENT_PROJECT:-}" ]; then
        __vjagent_carry="-e"
      fi
      exec ${lib.getExe pkgs.vj.tmux} new-session \
        ''${__vjagent_carry:+"$__vjagent_carry" "VJAGENT_PROJECT=$VJAGENT_PROJECT"} \
        -- "$__vjagent_self" "$@"
    fi
  '';

  agentHook = command: {
    hooks = [
      {
        type = "command";
        inherit command;
      }
    ];
  };

  agentHome = pkgs: {
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

  agentHooks = pkgs: let
    vjprojExe = lib.getExe pkgs.vj.vjproj;
    report = activity: agentHook "${vjprojExe} agent report --activity ${activity}";
  in {
    UserPromptSubmit = [(report "working")];
    PreToolUse = [(report "working")];
    PostToolUse = [(report "working")];
    Stop = [(report "idle")];
    SessionEnd = [(agentHook "${vjprojExe} agent end")];
  };
in {
  lib = {inherit agentTmux agentHook agentHome agentHooks;};

  wrappers._agent = {
    lib,
    pkgs,
    config,
    ...
  }: {
    options.agent = {
      kind = lib.mkOption {
        type = lib.types.str;
        description = "Name vjproj files this agent's sessions under";
      };

      configVar = lib.mkOption {
        type = lib.types.str;
        description = "Variable the agent reads its configuration directory from";
      };

      directory = lib.mkOption {
        type = lib.types.str;
        default = config.agent.kind;
        description = "Name of that directory under ~/.local/share";
      };

      instructions = lib.mkOption {
        type = lib.types.str;
        default = "AGENTS.md";
        description = "File the shared vjenv instructions are copied to";
      };
    };

    config = {
      binName = lib.mkDefault config.agent.kind;
      env.__NIXOS_SET_ENVIRONMENT_DONE = "1";

      runShell = lib.mkMerge [
        (lib.mkBefore [
          (agentTmux pkgs)
          (agentHome pkgs {
            inherit (config.agent) instructions;
            var = config.agent.configVar;
            dir = config.agent.directory;
          })
          ''
            export VJAGENT_PID=$$
            export VJAGENT_KIND=${config.agent.kind}
          ''
        ])
        (lib.mkAfter [
          "${lib.getExe pkgs.vj.vjproj} agent report --activity idle || true"
        ])
      ];
    };
  };

  wrappers.gh = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.gh;
    runShell = [(self.lib.vjenv.gated pkgs "gh")];
  };
}

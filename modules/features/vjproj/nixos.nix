{
  self,
  lib,
  build,
  ...
}: {
  modules.nixos.desktop = {
    pkgs,
    config,
    ...
  }: {
    environment.systemPackages = [pkgs.vj.vjproj];

    environment.etc."vjproj/system.json".text = builtins.toJSON {
      inherit (config.system.nixos) release;
      revision = config.system.configurationRevision;
      built = build.lastModified;
    };

    networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
      443
      self.lib.vjproj.port
    ];

    systemd.services.vjproj-https = {
      description = "Front the vjproj page with the tailnet's own certificate";
      after = ["tailscaled.service"];
      wants = ["tailscaled.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 30;
        ExecStart = "${lib.getExe' pkgs.tailscale "tailscale"} serve --bg --https=443 127.0.0.1:${toString self.lib.vjproj.port}";
        ExecStop = "${lib.getExe' pkgs.tailscale "tailscale"} serve --https=443 off";
      };
    };

    systemd.user.services.vjproj-serve = {
      description = "Your agents, reachable from your phone over the tailnet";
      partOf = ["graphical-session.target"];
      after = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];

      path = [pkgs.vj.claude-per pkgs.vj.claude-fish pkgs.vj.codex pkgs.vj.opencode pkgs.vj.fish];

      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.vj.vjproj} serve --port ${toString self.lib.vjproj.port}";
        Restart = "always";
        RestartSec = 5;
        KillMode = "process";
      };
    };

    persistence.data.directories = [
      ".local/share/vjproj"
    ];
  };
}

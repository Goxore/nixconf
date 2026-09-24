{lib, ...}: let
  snapshot = import ./_config-snapshot.nix;
  service = settings: (snapshot {systemd.services.example = settings;}).systemdServices;
  firewall = settings: (snapshot {networking.firewall = settings;}).firewall;
  persistence = mode:
    (snapshot {
      environment.persistence."/persist" = {
        directories = [
          {
            directory = "/var/lib/example";
            inherit mode;
          }
        ];
      };
    }).persistence;
  failures = lib.runTests {
    testRestartPolicy = {
      expr = service {serviceConfig.Restart = "always";} != service {serviceConfig.Restart = "on-failure";};
      expected = true;
    };
    testOrdering = {
      expr = service {after = ["network.target"];} != service {after = ["network-online.target"];};
      expected = true;
    };
    testCommandArguments = {
      expr = service {serviceConfig.ExecStart = "/nix/store/00000000000000000000000000000000-app/bin/app --port 80";} != service {serviceConfig.ExecStart = "/nix/store/11111111111111111111111111111111-app/bin/app --port 443";};
      expected = true;
    };
    testStoreHashNoise = {
      expr = service {serviceConfig.ExecStart = "/nix/store/00000000000000000000000000000000-app/bin/app";};
      expected = service {serviceConfig.ExecStart = "/nix/store/11111111111111111111111111111111-app/bin/app";};
    };
    testInterfacePorts = {
      expr = firewall {interfaces.tailscale0.allowedTCPPorts = [8422];} != firewall {interfaces.tailscale0.allowedTCPPorts = [443 8422];};
      expected = true;
    };
    testTrustedInterfaces = {
      expr = firewall {trustedInterfaces = [];} != firewall {trustedInterfaces = ["eth0"];};
      expected = true;
    };
    testPortRanges = {
      expr =
        firewall {allowedUDPPortRanges = [];}
        != firewall {
          allowedUDPPortRanges = [
            {
              from = 1000;
              to = 2000;
            }
          ];
        };
      expected = true;
    };
    testPersistencePermissions = {
      expr = persistence "0700" != persistence "0755";
      expected = true;
    };
  };
in {
  checks = pkgs: {
    config-snapshot = assert failures == []; pkgs.runCommand "config-snapshot-check" {} "touch $out";
  };
}

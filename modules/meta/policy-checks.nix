{
  self,
  lib,
  ...
}: {
  checks = pkgs:
    lib.mapAttrs' (name: host: let
      c = host.config;
      user = c.users.users.${c.preferences.user.name};
      firewall = c.networking.firewall;
      tailnet = firewall.interfaces.${c.services.tailscale.interfaceName};
    in
      lib.nameValuePair "${name}-security" (
        assert firewall.enable;
        assert user.initialPassword == null;
        assert user.password == null;
        assert user.hashedPasswordFile != null;
        assert builtins.elem "z ${user.hashedPasswordFile} 0600 root root - -" c.systemd.tmpfiles.rules;
        assert lib.hasPrefix (
          if c.persistence.enable
          then "/persist/"
          else "/var/lib/"
        )
        user.hashedPasswordFile;
        assert c.services.tailscale.openFirewall;
        assert builtins.elem 443 tailnet.allowedTCPPorts;
        assert builtins.elem self.lib.vjproj.port tailnet.allowedTCPPorts;
        assert !(builtins.elem self.lib.vjproj.port firewall.allowedTCPPorts);
        assert !(builtins.elem 67 firewall.allowedUDPPorts);
          pkgs.runCommand "${name}-security-check" {} "touch $out"
      ))
    self.nixosConfigurations
    // {
      hotspot-security = let
        c = self.nixosConfigurations.main.config;
        service = c.systemd.services.create_ap.serviceConfig;
        wrapped = "${pkgs.vj.hotspot}/bin/.create_ap-wrapped";
      in
        assert !(c.services.create_ap.settings ? PASSPHRASE);
        assert service.StateDirectory == "hotspot";
        assert builtins.elem "/var/lib/hotspot" c.persistence.directories;
        assert service.RuntimeDirectoryMode == "0700";
          pkgs.runCommand "hotspot-security-check" {} ''
            test "$(grep -c 'INPUT -i' "${wrapped}")" -eq 6
            ! grep -E 'INPUT -p' "${wrapped}"
            touch "$out"
          '';
    };
}

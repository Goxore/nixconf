{
  config,
  pkgs,
  lib,
  ...
}:
with lib; {
  users.users.satisfactory = {
    home = "/var/lib/satisfactory";
    createHome = true;
    isSystemUser = true;
    group = "satisfactory";
  };
  users.groups.satisfactory = {};

  # boot.kernel.sysctl."net.ipv6.conf.eth0.disable_ipv6" = true;
  networking.enableIPv6 = false;

  # nixpkgs.config.allowUnfree = true;
  #
  networking = {
    firewall = {
      allowedUDPPorts = [15777 15000 7777 27015];
      allowedUDPPortRanges = [
        {
          from = 27031;
          to = 27036;
        }
      ];
      allowedTCPPorts = [27015 27036];
    };
  };

  # -beta experimental \
  systemd.services.satisfactory = {
    preStart = ''
      ${pkgs.steamcmd}/bin/steamcmd \
        +force_install_dir /var/lib/satisfactory/SatisfactoryServer \
        +login anonymous \
        +app_update 1690800 \
        validate \
        +quit
    '';
    script = ''
      ${pkgs.steam-run}/bin/steam-run /var/lib/satisfactory/SatisfactoryServer/FactoryServer.sh -DisablePacketRouting
    '';
    serviceConfig = {
      Nice = "-5";
      Restart = "always";
      User = "satisfactory";
      WorkingDirectory = "/var/lib/satisfactory";
    };
  };
}

{
  packages = pkgs: {
    hotspot = pkgs.linux-wifi-hotspot.overrideAttrs (previous: {
      postPatch =
        (previous.postPatch or "")
        + ''
          substituteInPlace src/scripts/create_ap \
            --replace-fail 'INPUT -p' 'INPUT -i "''${WIFI_IFACE}" -p'
        '';
    });
  };

  hosts.main = {
    config,
    lib,
    pkgs,
    ...
  }: let
    settings =
      pkgs.writeText "create_ap.conf"
      (lib.generators.toKeyValue {} config.services.create_ap.settings);

    start = pkgs.writeShellApplication {
      name = "create_ap-start";

      runtimeInputs = [pkgs.coreutils];

      text = ''
        passphrase="$STATE_DIRECTORY/passphrase"
        if [ ! -s "$passphrase" ]; then
          install -m 0640 -g users /dev/null "$passphrase.new"
          head -c 512 /dev/urandom | tr -dc 'a-km-z2-9' | cut -c1-16 > "$passphrase.new"
          mv "$passphrase.new" "$passphrase"
        fi

        conf="$RUNTIME_DIRECTORY/create_ap.conf"
        install -m 0600 /dev/null "$conf"
        {
          cat ${settings}
          printf 'PASSPHRASE=%s\n' "$(cat "$passphrase")"
        } > "$conf"

        exec ${pkgs.vj.hotspot}/bin/create_ap --config "$conf"
      '';
    };
  in {
    services.create_ap = {
      enable = true;
      settings = {
        INTERNET_IFACE = "enp14s0";
        WIFI_IFACE = "wlp15s0";
        SSID = "TROJANVIRUS67";

        FREQ_BAND = "5";
        COUNTRY = "UA";
        CHANNEL = "36";
        IEEE80211N = "1";
        IEEE80211AC = "1";
        IEEE80211AX = "1";
        HT_CAPAB = "[HT40+]";
      };
    };

    persistence.directories = ["/var/lib/hotspot"];

    networking.networkmanager.unmanaged = ["wlp15s0"];

    networking.firewall.interfaces.ap0 = {
      allowedTCPPorts = [5353];
      allowedUDPPorts = [67 5353];
    };

    systemd.services.create_ap = {
      wantedBy = lib.mkForce [];
      after = ["sys-subsystem-net-devices-wlp15s0.device"];
      bindsTo = ["sys-subsystem-net-devices-wlp15s0.device"];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        ExecStart = lib.mkForce (lib.getExe start);
        RuntimeDirectory = "create_ap";
        RuntimeDirectoryMode = "0700";
        RestartSec = 3;
        StateDirectory = "hotspot";
        StateDirectoryMode = "0755";
      };
    };
  };
}

{
  inputs,
  self,
  ...
}: let
  runtime = pkgs: [
    pkgs.android-tools
    pkgs.avahi
    pkgs.coreutils
    pkgs.curl
    pkgs.iproute2
    pkgs.iw
    pkgs.pulseaudio
    pkgs.systemd
  ];
in {
  lib.vjvrUnwrapped = pkgs:
    self.lib.rustCrate pkgs "vjvr" {};

  packages = pkgs: {
    inherit (pkgs) wivrn;

    vjvr = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = self.lib.vjvrUnwrapped pkgs;
      binName = "vjvr";
      runtimePkgs =
        map (package: {
          data = package;
          prefix = true;
        })
        (runtime pkgs);
      envDefault.VJVR_CONFIG = "/etc/vjvr.json";
    };
  };

  devShells = pkgs: {
    vjvr = self.lib.rustShell pkgs (runtime pkgs);
  };

  checks = pkgs: {
    vjvr-service =
      pkgs.runCommand "vjvr-service-check" {
        nativeBuildInputs = [(pkgs.python3.withPackages (p: [p.dbus-next])) pkgs.dbus];
      } ''
        dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- \
          python3 ${./tests/service.py} ${self.lib.vjvrUnwrapped pkgs}/bin/vjvr
        touch $out
      '';
  };
}

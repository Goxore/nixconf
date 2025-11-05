{
  flake.nixosModules.powersave = {
    pkgs,
    lib,
    ...
  }: let
    inherit (lib) getExe getExe';

    makePowerScript = name: gpuLevel: profile:
      pkgs.writeShellApplication {
        inherit name;
        text = ''
          sudo ${getExe pkgs.yq} -i -y '.gpus[] |= (.performance_level = "${gpuLevel}")' /etc/lact/config.yaml
          ${getExe' pkgs.power-profiles-daemon "powerprofilesctl"} set ${profile}
        '';
      };

    sys-powersave = makePowerScript "sys-powersave" "low" "power-saver";
    sys-powerauto = makePowerScript "sys-auto" "auto" "balanced";
  in {
    services.power-profiles-daemon.enable = true;

    hardware.amdgpu.overdrive.enable = true;
    services.lact.enable = true;

    environment.systemPackages = [
      sys-powersave
      sys-powerauto
    ];
  };
}

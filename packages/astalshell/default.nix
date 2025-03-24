{
  nixpkgs,
  astal,
  system,
  ...
}: let
  pkgs = nixpkgs.legacyPackages.${system};
  astalpkgs = astal.packages.${system};
in
  astal.lib.mkLuaPackage {
    inherit pkgs;
    name = "my-shell";
    src = ./.;

    extraLuaPackages = ps:
      with ps; [
        http
        dkjson
      ];

    extraPackages = with astalpkgs; [
      battery
      astal4
      mpris
      apps
      astal3
      astal4
      battery
      bluetooth
      cava
      greet
      hyprland
      io
      mpris
      network
      notifd
      powerprofiles
      tray
      wireplumber

      pkgs.dart-sass
    ];
  }

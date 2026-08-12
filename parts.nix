{inputs, ...}: {
  imports = [
    inputs.wrapper-modules.flakeModules.wrappers
  ];

  config = {
    perSystem = {system, ...}: {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (_: prev: {
            mango = prev.mango.overrideAttrs (_: {
              version = "0.16.0";
              src = prev.fetchFromGitHub {
                owner = "mangowm";
                repo = "mango";
                tag = "0.16.0";
                hash = "sha256-ERtlCk10ortjvBcyovnFVUwwPifSw/rORgVtCbmUsFU=";
              };
            });
          })
          (inputs.nixpkgs-multiverse.lib.pinOverlay {
            pins."godot-mono" = "4.6.3-stable";
          })
        ];
      };
    };

    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}

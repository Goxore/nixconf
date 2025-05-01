inputs: let
  myLib = (import ./default.nix) {inherit inputs;};
  outputs = inputs.self.outputs;
  nixpkgs = inputs.nixpkgs;
in rec {
  # ================================================================ #
  # =                            My Lib                            = #
  # ================================================================ #

  # =========================== Helpers ============================ #

  myOverlays = import ./../overlays {inherit inputs outputs;};

  pkgsFor = system:
    import nixpkgs {
      inherit system;
      overlays = myOverlays;
    };

  overlayModule = {
    nixpkgs.overlays = myOverlays;
  };

  # ========================== Buildables ========================== #

  mkSystem = config:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs outputs myLib;
      };
      modules = [
        config
        outputs.nixosModules.default
        overlayModule

        ({pkgs, ...}: {nix.package = pkgs.lix;})
      ];
    };

  mkHome = sys: config:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor sys;
      extraSpecialArgs = {
        inherit inputs myLib outputs;
      };
      modules = [
        # TODO: move this
        inputs.stylix.homeManagerModules.stylix
        {
          stylix.image = ./../nixosModules/features/stylix/gruvbox-mountain-village.png;
          nixpkgs.config.allowUnfree = true;
        }

        config
        outputs.homeManagerModules.default
      ];
    };

  # =========================== Helpers ============================ #

  filesIn = dir: (map (fname: dir + "/${fname}")
    (builtins.attrNames (builtins.readDir dir)));

  dirsIn = dir:
    nixpkgs.lib.filterAttrs (name: value: value == "directory")
    (builtins.readDir dir);

  fileNameOf = path: (builtins.head (builtins.split "\\." (baseNameOf path)));

  # ========================== Extenders =========================== #

  # Evaluates nixos/home-manager module and extends it's options / config
  # I don't use it anymore, but left just in case
  extendModule = {path, ...} @ args: {pkgs, ...} @ margs: let
    eval =
      if (builtins.isString path) || (builtins.isPath path)
      then import path margs
      else path margs;
    evalNoImports = builtins.removeAttrs eval ["imports" "options"];

    extra =
      if (builtins.hasAttr "extraOptions" args) || (builtins.hasAttr "extraConfig" args)
      then [
        ({...}: {
          options = args.extraOptions or {};
          config = args.extraConfig or {};
        })
      ]
      else [];
  in {
    imports =
      (eval.imports or [])
      ++ extra;

    options =
      if builtins.hasAttr "optionsExtension" args
      then (args.optionsExtension (eval.options or {}))
      else (eval.options or {});

    config =
      if builtins.hasAttr "configExtension" args
      then (args.configExtension (eval.config or evalNoImports))
      else (eval.config or evalNoImports);
  };

  # Applies extendModules to all modules
  # modules can be defined in the same way
  # as regular imports, or taken from "filesIn"
  # I don't use it anymore, but left just in case
  extendModules = extension: modules:
    map
    (f: let
      name = fileNameOf f;
    in (extendModule ((extension name) // {path = f;})))
    modules;

  # ============================ Shell ============================= #
  # forAllSystems = pkgs:
  #   inputs.nixpkgs.lib.genAttrs [
  #     "x86_64-linux"
  #     "aarch64-linux"
  #     "x86_64-darwin"
  #     "aarch64-darwin"
  #   ]
  #   (system: pkgs inputs.nixpkgs.legacyPackages.${system});
}

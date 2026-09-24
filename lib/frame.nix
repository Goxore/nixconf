{
  inputs,
  root,
  build,
}: let
  inherit (inputs.nixpkgs) lib;

  isNixModule = file:
    file.hasExt "nix"
    && !lib.hasPrefix "_" file.name;

  modules = lib.fileset.toList (lib.fileset.fileFilter isNixModule (root + "/modules"));

  outputs = lib.mkOptionType {
    name = "outputs";
    description = "flake output values";
    descriptionClass = "noun";
    merge = loc: defs:
      if builtins.length defs == 1
      then (builtins.head defs).value
      else if builtins.all builtins.isAttrs (lib.options.getValues defs)
      then (lib.types.lazyAttrsOf outputs).merge loc defs
      else
        throw ''
          The option `${lib.showOption loc}' has conflicting definitions in
          ${lib.options.showFiles (lib.options.getFiles defs)}
        '';
  };

  optFunctionTo = elemType: let
    nonFunction = lib.mkOptionType {
      name = "nonFunction";
      description = "non-function";
      descriptionClass = "noun";
      check = x: !lib.isFunction x && elemType.check x;
      merge = lib.options.mergeOneOption;
    };
  in
    lib.types.coercedTo nonFunction (x: _: x) (lib.types.functionTo elemType);

  perSystemAttr = optFunctionTo (lib.types.lazyAttrsOf lib.types.package);

  published = [
    "lib"
    "nixosConfigurations"
  ];

  core = {
    freeformType = lib.types.lazyAttrsOf outputs;

    options = {
      systems = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };

      nixpkgsOverlays = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [];
        description = ''
          Overlays applied to the nixpkgs instance every system is built from.
          Contributed by the feature that needs the override, not centrally.
        '';
      };

      packages = lib.mkOption {
        type = perSystemAttr;
        default = {};
        description = "Packages this flake builds, each a function of pkgs";
      };

      checks = lib.mkOption {
        type = perSystemAttr;
        default = {};
      };

      devShells = lib.mkOption {
        type = perSystemAttr;
        default = {};
      };

      formatter = lib.mkOption {
        type = lib.types.nullOr (optFunctionTo lib.types.package);
        default = null;
      };

      nixosConfigurations = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = {};
      };
    };
  };

  perSystemOutputs = {
    packages = builtins.mapAttrs (_: pkgs: pkgs.vj) pkgsFor;
    checks = genSystems frame.config.checks;
    devShells = genSystems frame.config.devShells;
    formatter =
      lib.optionalAttrs (frame.config.formatter != null)
      (genSystems frame.config.formatter);
  };

  vjOverlay = final: _prev: {vj = frame.config.packages final;};

  pkgsFor = lib.genAttrs frame.config.systems (system:
    import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = frame.config.nixpkgsOverlays ++ [vjOverlay];
    });

  genSystems = f: builtins.mapAttrs (_: f) pkgsFor;

  frame = lib.evalModules {
    class = "frame";
    specialArgs = {
      inherit inputs pkgsFor build;
      inherit (frame.config) wrapperModules;
      self = frame.config;
      inherit root;
    };
    modules = modules ++ [core];
  };

  flakeOutputs =
    lib.getAttrs (builtins.filter (name: frame.config ? ${name}) published) frame.config
    // perSystemOutputs;
in
  flakeOutputs

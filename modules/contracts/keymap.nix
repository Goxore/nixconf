{
  lib,
  config,
  ...
}: let
  desc = lib.mkOption {
    type = lib.types.str;
    description = "Label shown to the user";
  };

  order = lib.mkOption {
    type = lib.types.int;
    default = 50;
    description = "Sort key for the menu; ties break on the key itself";
  };

  spawn = lib.types.either lib.types.str (lib.types.functionTo lib.types.str);

  cmd = lib.mkOption {
    type = spawn;
    description = ''
      Command to run. A function receives {pkgs, vjshell} for entries that
      need a store path or the live-reloadable shell.
    '';
  };

  bind = lib.types.submodule {
    options = {inherit desc order cmd;};
  };

  pointer = lib.types.submodule {
    options = {inherit desc cmd;};
  };

  menu = lib.types.submodule {
    options = {
      inherit desc order;

      icon = lib.mkOption {
        type = lib.types.str;
        description = "Material Symbols Rounded glyph shown on the menu tile";
      };

      cmd = lib.mkOption {
        type = lib.types.nullOr spawn;
        default = null;
        description = ''
          Program to spawn. A function receives {pkgs} for entries that need a
          store path. Mutually exclusive with action.
        '';
      };

      action = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Name of an action vjshell performs itself, such as "bluetooth.toggle".
          Entries that drive the shell use this instead of shelling out to it.
          Mutually exclusive with cmd.
        '';
      };
    };
  };

  resolve = ctx: cmd:
    if lib.isFunction cmd
    then cmd ctx
    else cmd;

  byOrder = a: b:
    if a.order != b.order
    then a.order < b.order
    else a.key < b.key;
in {
  options.keymap = lib.mkOption {
    type = lib.types.submodule {
      options = {
        binds = lib.mkOption {
          type = lib.types.lazyAttrsOf bind;
          default = {};
          description = ''
            Compositor binds, keyed by the mango chord that triggers them
            (e.g. "SUPER,v"). Declared by the feature that owns the action.
          '';
        };

        mouse = lib.mkOption {
          type = lib.types.lazyAttrsOf pointer;
          default = {};
          description = ''
            Compositor pointer binds, keyed by the mango chord that triggers
            them (e.g. "SUPER,btn_middle"). Declared by the feature that owns
            the action.
          '';
        };

        menu = lib.mkOption {
          type = lib.types.lazyAttrsOf menu;
          default = {};
          description = ''
            Entries of the SUPER+d menu, keyed by their trigger key.
          '';
        };
      };
    };
    default = {};
  };

  config.lib.keymap = {
    inherit resolve;

    menuEntries = ctx:
      map (
        entry:
          lib.throwIf ((entry.cmd == null) == (entry.action == null))
          "keymap menu entry ${entry.key} must set exactly one of cmd or action"
          {
            inherit (entry) key desc icon;
            cmd =
              if entry.cmd == null
              then ""
              else resolve ctx entry.cmd;
            action =
              if entry.action == null
              then ""
              else entry.action;
          }
      )
      (lib.sort byOrder
        (lib.mapAttrsToList (key: entry: entry // {inherit key;})
          config.keymap.menu));
  };
}

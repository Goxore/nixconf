{
  modules.nixos.base = {
    lib,
    config,
    ...
  }: let
    entries = lib.types.listOf (lib.types.either lib.types.str (lib.types.attrsOf lib.types.anything));

    scope = subject: {
      directories = lib.mkOption {
        type = entries;
        default = [];
        description = "Directories to persist, ${subject}";
      };

      files = lib.mkOption {
        type = entries;
        default = [];
        description = "Files to persist, ${subject}";
      };
    };
  in {
    options.persistence =
      {
        enable = lib.mkEnableOption "persistence across reboots";

        user = lib.mkOption {
          type = lib.types.str;
          default = config.preferences.user.name;
          description = "User whose home the data and cache scopes are relative to";
        };

        data = scope "relative to the main user's home, under /persist/userdata";
        cache = scope "relative to the main user's home, under /persist/usercache";
      }
      // scope "as absolute paths, under /persist/system";
  };
}

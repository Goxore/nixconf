{
  inputs,
  self,
  ...
}: {
  perSystem = {pkgs, ...}: let
    # defaultRevset = "present(@) | ancestors(immutable_heads()) | present(trunk())";
    defaultRevset = "all()";
  in {
    packages.jjui =
      (self.wrapperModules.jjui.apply {
        inherit pkgs;
        settings = {
          preview = {
            show_at_start = true;
          };
        };
        flags = {
          "-r" = defaultRevset;
        };
      }).wrapper;

    packages.jujutsu = let
      logCommand = ["log" "--reversed" "--no-pager" "-r" defaultRevset "-n" "20"];
    in
      (inputs.wrappers.wrapperModules.jujutsu.apply {
        inherit pkgs;
        settings = {
          user = {
            name = "Yurii";
            email = "yurii@goxore.com";
          };
          aliases = {
            l = logCommand;
          };
          ui = {
            default-command = logCommand;
          };
          snapshot = {
            max-new-file-size = "15MiB";
          };
        };
      }).wrapper;
  };

  flake.wrapperModules.jjui = inputs.wrappers.lib.wrapModule (
    {
      config,
      lib,
      ...
    }: let
      tomlFormat = config.pkgs.formats.toml {};
    in {
      options = {
        settings = lib.mkOption {
          type = tomlFormat.type;
        };
      };

      config = {
        package = config.pkgs.jjui;

        env = {
          JJUI_CONFIG_DIR = let
            generatedFile = tomlFormat.generate "config.toml" config.settings;

            configDir = config.pkgs.runCommand "jjui-config-dir" {} ''
              mkdir -p $out
              cp ${generatedFile} $out/config.toml
            '';
          in "${configDir}";
        };
      };
    }
  );
}

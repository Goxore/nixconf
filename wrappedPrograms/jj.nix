{
  flake.wrappers.jujutsu = {wlib, ...}: let
    logCommand = ["log" "--reversed" "--no-pager" "-r" "all()" "-n" "20"];
  in {
    imports = [wlib.wrapperModules.jujutsu];
    settings = {
      user = {
        name = "Yurii";
        email = "yurii@goxore.com";
      };
      aliases.l = logCommand;
      ui.default-command = logCommand;
      snapshot.max-new-file-size = "50MiB";
    };
  };

  flake.wrappers.jjui = {
    wlib,
    pkgs,
    config,
    lib,
    ...
  }: let
    tomlFormat = pkgs.formats.toml {};
  in {
    imports = [wlib.modules.default];
    options.settings = lib.mkOption {
      type = tomlFormat.type;
    };
    config = {
      package = pkgs.jjui;
      settings = {
        preview.show_at_start = true;
      };
      flags = {
        "-r" = "all()";
      };
      env.JJUI_CONFIG_DIR = let
        generatedFile = tomlFormat.generate "config.toml" config.settings;
        configDir = pkgs.runCommand "jjui-config-dir" {} ''
          mkdir -p $out
          cp ${generatedFile} $out/config.toml
        '';
      in "${configDir}";
    };
  };
}

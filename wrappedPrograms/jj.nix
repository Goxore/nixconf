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
      revsets = {
        log-graph-prioritize = "default@";
      };
    };
  };

  flake.wrappers.jujutsuvj = {wlib, ...}: let
    logCommand = ["log" "--reversed" "--no-pager" "-r" "all()" "-n" "20"];
  in {
    imports = [wlib.wrapperModules.jujutsu];
    settings = {
      user = {
        name = "Vimjoyer";
        email = "vimjoyer@gmail.com";
      };
      aliases.l = logCommand;
      ui.default-command = logCommand;
      snapshot.max-new-file-size = "50MiB";
      revsets = {
        log-graph-prioritize = "default@";
      };
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

  perSystem = {
    pkgs,
    self',
    ...
  }: {
    devShells.vjenv = pkgs.mkShell {
      env = {
        GIT_AUTHOR_NAME = "Vimjoyer";
        GIT_AUTHOR_EMAIL = "vimjoyer@gmail.com";
        GIT_COMMITTER_NAME = "Vimjoyer";
        GIT_COMMITTER_EMAIL = "vimjoyer@gmail.com";
      };
      shellHook = ''
        export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_rsa_vimjoyer -o IdentitiesOnly=yes"
        export GH_CONFIG_DIR="$HOME/.config/gh-vimjoyer"
      '';
      packages = [
        self'.packages.jujutsuvj
        pkgs.gh
      ];
    };
  };
}

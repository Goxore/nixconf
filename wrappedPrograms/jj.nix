{self, ...}: {
  flake.wrappers.jujutsu = {
    wlib,
    pkgs,
    ...
  }: let
    logCommand = ["log" "--reversed" "--no-pager" "-r" "all()" "-n" "20"];
  in {
    imports = [wlib.wrapperModules.jujutsu];

    settings = {
      aliases.l = logCommand;
      ui.default-command = logCommand;
      ui.merge-editor = "nvimdiff";
      snapshot.max-new-file-size = "50MiB";
      snapshot.auto-update-stale = true;
      revsets = {
        log-graph-prioritize = "present(default@) | present(main)";
      };

      merge-tools.nvimdiff = {
        program = "nvim";
        merge-args = [
          "-f"
          "-d"
          "$output"
          "-M"
          "$left"
          "$base"
          "$right"
          "-c"
          "wincmd J"
          "-c"
          "set modifiable"
          "-c"
          "set write"
          "-c"
          "/<<<<<</+2"
        ];
        merge-tool-edits-conflict-markers = true;
        edit-args = ["-f" "-d" "$left" "$right"];
      };

      colors.trunk_bookmark = {
        fg = self.theme.base0A;
        bold = true;
        underline = true;
      };

      colors."node immutable" = {
        fg = self.theme.base0A;
        bold = true;
      };

      template-aliases."format_short_commit_header(commit)" = ''
        separate(" ",
          format_short_change_id_with_change_offset(commit),
          format_short_signature(commit.author()),
          format_timestamp(commit_timestamp(commit)),
          commit.bookmarks().map(|b|
            label(if(b.name() == "main", "trunk_bookmark"), b)
          ).join(" "),
          commit.tags(),
          commit.working_copies(),
          format_short_commit_id(commit.commit_id()),
          format_commit_labels(commit),
          if(config("ui.show-cryptographic-signatures").as_boolean(),
            format_short_cryptographic_signature(commit.signature())
          ),
        )
      '';
    };

    runShell = [(self.lib.vjenv.env pkgs)];
  };

  flake.wrappers.jjui = {
    wlib,
    pkgs,
    config,
    lib,
    ...
  }: let
    tomlFormat = pkgs.formats.toml {};
    editor = lib.getExe self.packages."${pkgs.stdenv.hostPlatform.system}".neovimDynamic;
    allRevset = "all()";
    mineRevset = "present(@) | ancestors(mine() & mutable(), 2) | present(trunk())";
  in {
    imports = [wlib.modules.default];
    options.settings = lib.mkOption {
      type = tomlFormat.type;
    };
    config = {
      package = pkgs.jjui;
      settings = {
        preview.show_at_start = true;
        suggest.exec.mode = "fuzzy";
        actions = [
          {
            name = "edit-file";
            desc = "edit file";
            lua =
              #lua
              ''
                local file = context.file()
                if not file then
                  return
                end
                exec_shell(string.format("%s %q", os.getenv("EDITOR") or "${editor}", file))
              '';
            key = "e";
            scope = "revisions.details";
          }
          {
            name = "toggle-mine";
            desc = "toggle mine/all";
            lua =
              #lua
              ''
                if revset.current() == "${mineRevset}" then
                  revset.set("${allRevset}")
                else
                  revset.set("${mineRevset}")
                end
              '';
            key = "m";
            scope = "revisions";
          }
          # {
          #   name = "goto-main";
          #   desc = "go to main";
          #   lua =
          #     #lua
          #     ''
          #       local out = jj("log", "--no-graph", "-r", "present(main)", "-T", [[change_id.short() ++ "\n"]])
          #       local ids = split_lines(out or "")
          #       if #ids == 0 then
          #         flash({text = "no main bookmark", error = true})
          #         return
          #       end
          #       revisions.navigate({to = ids[1]})
          #     '';
          #   seq = ["f" "m"];
          #   scope = "revisions";
          # }
        ];
      };
      flags = {
        "-r" = allRevset;
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

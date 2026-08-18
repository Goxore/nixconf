{self, ...}: {
  flake.nixosModules.firefox = {
    pkgs,
    config,
    ...
  }: let
    inherit (self) theme darken;

    user = config.preferences.user.name;
    profile = user;

    midnightCss = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/refact0r/midnight-discord/151176d321c8feb08f939fad0c69693947b73dda/build/midnight.css";
      hash = "sha256-+VTFyp2y9FywZ0jpMIwJ3I+80QZ8SNn2uq976whyLf0=";
    };

    system24Css = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/refact0r/system24/e620464b32ccc0ddbd8e17e3ae351023ba900e6d/build/system24.css";
      hash = "sha256-loIoJh88eRh2KT31cM6zdNKBTQu+6q8vXhwV3qpojGU=";
    };

    discordCss =
      pkgs.runCommand "discord-gruvbox.css" {
        variables = self.discordTheme.variables;
        passAsFile = ["variables"];
      } ''
        {
          echo '@-moz-document domain("discord.com") {'
          cat ${midnightCss} ${system24Css} "$variablesPath" \
            | grep -v '^@import' \
            | awk -f ${./_importantify.awk}
          echo '}'
        } > $out
      '';

    userChrome = ''
      :root {
        --lwt-accent-color: ${theme.base00} !important;
        --lwt-accent-color-inactive: ${theme.base00} !important;
        --lwt-text-color: ${theme.base06} !important;
        --lwt-selected-tab-background-color: ${theme.base01} !important;
        --lwt-tab-line-color: ${theme.base0E} !important;
        --lwt-toolbar-field-background-color: ${theme.base01} !important;
        --lwt-toolbar-field-color: ${theme.base06} !important;
        --lwt-toolbar-field-focus: ${theme.base01} !important;
        --lwt-toolbar-field-focus-color: ${theme.base07} !important;
        --lwt-toolbar-field-border-color: transparent !important;

        --toolbar-bgcolor: ${theme.base00} !important;
        --toolbar-color: ${theme.base06} !important;
        --toolbar-field-background-color: ${theme.base01} !important;
        --toolbar-field-color: ${theme.base06} !important;
        --toolbar-field-focus-background-color: ${theme.base01} !important;
        --toolbar-field-focus-color: ${theme.base07} !important;
        --toolbar-field-border-color: transparent !important;
        --toolbarbutton-icon-fill: ${theme.base06} !important;
        --toolbarbutton-hover-background: ${theme.base02} !important;
        --toolbarbutton-active-background: ${theme.base03} !important;
        --toolbarseparator-color: ${theme.base02} !important;

        --tab-selected-bgcolor: ${theme.base01} !important;
        --tab-selected-textcolor: ${theme.base07} !important;
        --tab-hover-background-color: ${theme.base01} !important;

        --arrowpanel-background: ${theme.base00} !important;
        --arrowpanel-color: ${theme.base06} !important;
        --arrowpanel-border-color: ${theme.base02} !important;
        --arrowpanel-dimmed: ${theme.base01} !important;
        --arrowpanel-dimmed-further: ${theme.base02} !important;

        --panel-background: ${theme.base00} !important;
        --panel-color: ${theme.base06} !important;
        --panel-border-color: ${theme.base02} !important;
        --panel-item-hover-bgcolor: ${theme.base02} !important;
        --panel-item-active-bgcolor: ${theme.base03} !important;

        --urlbar-box-bgcolor: ${theme.base01} !important;
        --urlbar-box-text-color: ${theme.base06} !important;
        --urlbar-box-hover-bgcolor: ${theme.base02} !important;
        --urlbarView-highlight-background: ${theme.base02} !important;
        --urlbarView-hover-background: ${theme.base01} !important;

        --sidebar-background-color: ${theme.base00} !important;
        --sidebar-text-color: ${theme.base06} !important;
        --sidebar-border-color: ${theme.base02} !important;

        --focus-outline-color: ${theme.base0E} !important;
        --button-primary-bgcolor: ${theme.base0E} !important;
        --button-primary-color: ${theme.base00} !important;

        --chrome-content-separator-color: ${theme.base02} !important;
      }

      #navigator-toolbox {
        background-color: ${theme.base00} !important;
        border-bottom: 1px solid ${theme.base02} !important;
      }

      #urlbar[focused="true"] > #urlbar-background {
        outline-color: ${theme.base0E} !important;
      }

      .tab-background[selected] {
        background-color: ${theme.base01} !important;
        outline: none !important;
      }

      .tabbrowser-tab[selected] .tab-label {
        color: ${theme.base07} !important;
      }

      findbar,
      #findbar-textbox {
        background-color: ${theme.base00} !important;
        color: ${theme.base06} !important;
      }

      #titlebar,
      #TabsToolbar,
      #tabbrowser-tabs,
      #nav-bar,
      #PersonalToolbar,
      #toolbar-menubar,
      #browser,
      #tabbrowser-tabbox,
      #sidebar-box,
      #sidebar-header,
      #sidebar-splitter,
      #appcontent {
        background-color: ${theme.base00} !important;
        color: ${theme.base06} !important;
      }

      #nav-bar,
      #PersonalToolbar {
        border: none !important;
        box-shadow: none !important;
      }

      #urlbar-background,
      #searchbar {
        background-color: ${theme.base01} !important;
        border-color: ${theme.base02} !important;
      }

      #urlbar[open] > #urlbar-background {
        background-color: ${theme.base01} !important;
      }

      .urlbarView,
      .urlbarView-body-inner,
      .urlbarView-results {
        background-color: ${theme.base01} !important;
        color: ${theme.base06} !important;
        border-color: ${theme.base02} !important;
      }

      .urlbarView-row:hover > .urlbarView-row-inner,
      .urlbarView-row[selected] > .urlbarView-row-inner {
        background-color: ${theme.base02} !important;
        color: ${theme.base07} !important;
      }

      .urlbarView-url,
      .search-panel-one-offs-container {
        color: ${theme.base0D} !important;
      }

      .urlbarView-title-separator,
      .urlbarView-secondary {
        color: ${theme.base04} !important;
      }

      menupopup,
      panel,
      .panel-arrowcontent,
      .menupopup-arrowscrollbox {
        background-color: ${theme.base01} !important;
        color: ${theme.base06} !important;
        --panel-background: ${theme.base01} !important;
      }

      menuitem:hover,
      menu:hover,
      .subviewbutton:hover,
      toolbarbutton.subviewbutton:hover {
        background-color: ${theme.base02} !important;
        color: ${theme.base07} !important;
      }

      menuseparator,
      toolbarseparator {
        border-color: ${theme.base02} !important;
      }

      #tabbrowser-tabpanels,
      browser[type="content"] {
        background-color: ${theme.base00} !important;
      }
    '';

    userContent = ''
      @-moz-document url-prefix("about:blank"), url("about:newtab"), url("about:home") {
        :root {
          --newtab-background-color: ${theme.base00} !important;
          --newtab-background-color-secondary: ${theme.base01} !important;
          --newtab-text-primary-color: ${theme.base06} !important;
          --newtab-primary-action-background: ${theme.base0E} !important;
        }
        body { background-color: ${theme.base00} !important; }
      }

      @-moz-document domain("youtube.com") {
        html, html[dark], ytd-app {
          --yt-spec-base-background: ${theme.base00} !important;
          --yt-spec-raised-background: ${theme.base01} !important;
          --yt-spec-menu-background: ${theme.base01} !important;
          --yt-spec-inverted-background: ${theme.base06} !important;
          --yt-spec-additive-background: ${theme.base01} !important;
          --yt-spec-general-background-a: ${theme.base00} !important;
          --yt-spec-general-background-b: ${theme.base00} !important;
          --yt-spec-general-background-c: ${theme.base01} !important;
          --yt-spec-brand-background-primary: ${theme.base00} !important;
          --yt-spec-brand-background-secondary: ${theme.base01} !important;
          --yt-spec-brand-background-solid: ${theme.base00} !important;
          --yt-spec-static-overlay-background-solid: ${theme.base00} !important;
          --yt-spec-badge-chip-background: ${theme.base01} !important;
          --yt-spec-10-percent-layer: ${theme.base02} !important;
          --yt-spec-outline: ${theme.base02} !important;

          --yt-spec-text-primary: ${theme.base06} !important;
          --yt-spec-text-secondary: ${theme.base04} !important;
          --yt-spec-text-disabled: ${theme.base03} !important;
          --yt-spec-wordmark-text: ${theme.base06} !important;
          --yt-spec-icon-active-other: ${theme.base04} !important;
          --yt-spec-icon-inactive: ${theme.base03} !important;
          --yt-spec-icon-disabled: ${theme.base03} !important;

          --yt-spec-call-to-action: ${theme.base0D} !important;
          --yt-spec-call-to-action-inverse: ${theme.base0D} !important;
          --yt-spec-suggested-action: ${theme.base02} !important;
          --yt-spec-themed-blue: ${theme.base0D} !important;
          --yt-spec-filled-button-text: ${theme.base00} !important;
          --yt-spec-static-brand-red: ${theme.base08} !important;
          --yt-spec-error-indicator: ${theme.base08} !important;
          --yt-spec-selected-nav-text: ${theme.base07} !important;
        }

        html[dark] {
          --ytcp-brand-background: ${theme.base00} !important;
          --ytcp-general-background-a: ${theme.base00} !important;
          --ytcp-general-background-b: ${theme.base01} !important;
          --ytcp-general-background-c: ${theme.base02} !important;
          --ytcp-menu-background: ${theme.base01} !important;
          --ytcp-container-border: ${theme.base02} !important;
          --ytcp-line-divider: ${theme.base02} !important;
          --ytcp-text-primary: ${theme.base06} !important;
          --ytcp-text-secondary: ${theme.base04} !important;
          --ytcp-text-disabled: ${theme.base03} !important;
          --ytcp-icon-fill: ${theme.base04} !important;
          --ytcp-call-to-action: ${theme.base0D} !important;
          --ytcp-suggested-action: ${theme.base0D} !important;
          --ytcp-overlay-background: ${darken 20 theme.base00} !important;
          --ytcp-video-thumbnail-background: ${theme.base01} !important;
        }

        body,
        ytd-app,
        tp-yt-app-drawer,
        ytcp-app {
          background-color: ${theme.base00} !important;
        }
      }

    '';

    userContentFile =
      pkgs.runCommand "userContent.css" {
        inherit userContent;
        passAsFile = ["userContent"];
      } ''
        cat "$userContentPath" ${discordCss} > $out
      '';
  in {
    programs.firefox = {
      enable = true;

      preferences = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.theme.dark-private-windows" = true;
        "browser.in-content.dark-mode" = true;
        "ui.systemUsesDarkTheme" = 1;
        "layout.css.prefers-color-scheme.content-override" = 0;
      };

      preferencesStatus = "default";
    };

    hjem.users.${user}.files = {
      ".mozilla/firefox/${profile}/chrome/userChrome.css".text = userChrome;
      ".mozilla/firefox/${profile}/chrome/userContent.css".source = userContentFile;
    };

    persistance.data.directories = [
      ".mozilla"
    ];

    persistance.cache.directories = [
      ".cache/mozilla"
    ];

    preferences.keymap = {
      "SUPER + d"."f".package = pkgs.firefox;
    };
  };
}

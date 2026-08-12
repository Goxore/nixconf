{self, ...}: let
  inherit (self) theme darken;
in {
  flake.discordTheme = {
    system24Url = "https://refact0r.github.io/system24/build/system24.css";

    variables = ''
      body {
          --font: 'JetBrainsMono Nerd Font';
          --code-font: 'JetBrainsMono Nerd Font';
          font-weight: 400;
          letter-spacing: -0.05ch;

          --gap: 12px;
          --divider-thickness: 4px;
          --border-thickness: 2px;
          --border-hover-transition: 0.2s ease;

          --animations: on;
          --list-item-transition: 0.2s ease;
          --dms-icon-svg-transition: 0.4s ease;

          --top-bar-height: var(--gap);
          --top-bar-button-position: titlebar;
          --top-bar-title-position: off;
          --subtle-top-bar-title: off;

          --custom-window-controls: off;
          --window-control-size: 14px;

          --custom-dms-icon: off;
          --custom-dms-background: off;

          --background-image: off;

          --transparency-tweaks: off;
          --remove-bg-layer: off;
          --panel-blur: off;
          --blur-amount: 12px;
          --bg-floating: var(--bg-3);

          --small-user-panel: on;
          --unrounding: on;

          --custom-spotify-bar: on;
          --ascii-titles: on;
          --ascii-loader: system24;

          --panel-labels: on;
          --label-color: var(--text-muted);
          --label-font-weight: 500;
      }

      body,
      .theme-dark:not(.custom-user-profile-theme),
      .theme-light:not(.custom-user-profile-theme) {
          --scrollbar-auto-scrollbar-color-thumb: ${theme.base02} !important;
          --scrollbar-auto-scrollbar-color-track: transparent !important;
      }

      :root {
          --colors: on;

          --text-0: var(--bg-4);
          --text-1: ${theme.base07};
          --text-2: ${theme.base06};
          --text-3: ${theme.base05};
          --text-4: ${theme.base04};
          --text-5: ${theme.base03};

          --bg-1: ${theme.base02};
          --bg-2: ${theme.base01};
          --bg-3: ${darken 35 theme.base00};
          --bg-4: ${theme.base00};
          --hover: var(--bg-2);
          --active: var(--bg-1);
          --active-2: ${theme.base03};
          --message-hover: var(--hover);

          --accent-1: var(--green-1);
          --accent-2: var(--green-2);
          --accent-3: var(--green-3);
          --accent-4: var(--green-4);
          --accent-5: var(--green-5);
          --accent-new: var(--red-2);
          --mention: linear-gradient(to right, color-mix(in hsl, var(--accent-2), transparent 90%) 40%, transparent);
          --mention-hover: linear-gradient(to right, color-mix(in hsl, var(--accent-2), transparent 95%) 40%, transparent);
          --reply: linear-gradient(to right, color-mix(in hsl, var(--text-3), transparent 90%) 40%, transparent);
          --reply-hover: linear-gradient(to right, color-mix(in hsl, var(--text-3), transparent 95%) 40%, transparent);

          --online: var(--green-2);
          --dnd: var(--red-2);
          --idle: var(--yellow-2);
          --streaming: var(--purple-2);
          --offline: var(--text-4);

          --border-light: var(--hover);
          --border: var(--active);
          --border-hover: ${theme.base0F};
          --button-border: hsl(220, 0%, 100%, 0.1);

          --red-1: ${theme.base08};
          --red-2: var(--red-1);
          --red-3: var(--red-1);
          --red-4: ${darken 25 theme.base08};
          --red-5: ${darken 60 theme.base08};

          --green-1: ${theme.base0B};
          --green-2: var(--green-1);
          --green-3: var(--green-1);
          --green-4: ${darken 25 theme.base0B};
          --green-5: ${darken 60 theme.base0B};

          --blue-1: ${theme.base0D};
          --blue-2: var(--blue-1);
          --blue-3: var(--blue-1);
          --blue-4: ${darken 25 theme.base0D};
          --blue-5: ${darken 60 theme.base0D};

          --yellow-1: ${theme.base0A};
          --yellow-2: var(--yellow-1);
          --yellow-3: var(--yellow-1);
          --yellow-4: ${darken 25 theme.base0A};
          --yellow-5: ${darken 60 theme.base0A};

          --purple-1: ${theme.base0E};
          --purple-2: var(--purple-1);
          --purple-3: var(--purple-1);
          --purple-4: ${darken 25 theme.base0E};
          --purple-5: ${darken 60 theme.base0E};
      }
    '';
  };
}

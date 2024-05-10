{pkgs, config, ...}: {
  home.packages = with pkgs; [
    vesktop
  ];

  myHomeManager.impermanence.cache.directories = [
    ".config/vesktop"
  ];

  xdg.configFile."vesktop/themes/nix-colors-theme.css" = {
    text = with config.stylix.base16Scheme; ''

      .theme-dark {
         --background-primary: #${base01};
         /* background of background of chat window */
         --background-secondary: #${base00};
         /* background of channel bar */
         --background-secondary-alt: #${base00};
         /* background of profile */
         --channeltextarea-background: ${base00};
         /* background of textarea */
         --background-tertiary: #${base01};
         /* background of channel bar */
         --background-accent: #${base04};
         --text-normal: #${base05};
         --text-spotify: #${base05};
         --text-muted: #${base04};
         --text-link: #${base0D};
         --bwckground-floating: #${base00};
         --header-primary: #${base07};
         --header-secondary: #${base04};
         --header-spotify: #${base04};
         --interactive-normal: #${base05};
         --interactive-hover: #${base07};
         --interactive-active: #${base07};
         --ping: #${base03};
         --background-modifier-selected: #${base03};
         --scrollbar-thin-thumb: #${base01};
         --scrollbar-thin-track: transparent;
         --scrollbar-auto-thumb: #${base01};
         --scrollbar-auto-track: transparent;
      }

      .body-2wLx-E,
      .headerTop-3GPUSF,
      .bodyInnerWrapper-2bQs1k,
      .footer-3naVBw {
        background-color: var(--background-tertiary);
      }

      .title-17SveM,
      .name-3Uvkvr {
        font-size: 12px;
      }

      .panels-3wFtMD {
        background-color: var(--background-secondary);
      }

      .username-h_Y3Us {
        font-family: var(--font-display);
        font-size: 12px;
      }

      .peopleColumn-1wMU14,
      .panels-j1Uci_,
      .peopleColumn-29fq28,
      .peopleList-2VBrVI,
      .content-2hZxGK,
      .header-1zd7se,

      .root-g14mjS .small-23Atuv .fullscreenOnMobile-ixj0e3 {
        background-color: var(--background-secondary);
      }

      .textArea-12jD-V,
      .lookBlank-3eh9lL,
      .threadSidebar-1o3BTy,
      .scrollableContainer-2NUZem,
      .perksModalContentWrapper-3RHugb,
      .theme-dark .footer-31IekZ,

      .theme-light .footer-31IekZ {
        background-color: var(--background-tertiary);
      }

      .numberBadge-2s8kKX,
      .base-PmTxvP,
      .baseShapeRound-1Mm1YW,
      .bar-30k2ka,
      .unreadMentionsBar-1Bu1dC,
      .mention-1f5kbO,
      .active-1SSsBb,

      .disableButton-220a9y {
        background-color: var(--ping) !important;
      }

      .lookOutlined-3sRXeN.colorRed-1TFJan,
      .lookOutlined-3sRXeN.colorRed-1TFJan {
        color: var(--ping) !important;
      }

      .header-3OsQeK,
      .container-ZMc96U {
        box-shadow: none !important;
        border: none !important;
      }

      .content-1gYQeQ,
      .layout-1qmrhw,
      .inputDefault-3FGxgL,
      .input-2g-os5,
      .input-2z42oC,
      .role-2TIOKu,

      .searchBar-jGtisZ {
        border-radius: 6px;
      }

      .layout-1qmrhw:hover,
      .content-1gYQeQ:hover {
        background-color: var(--background-modifier-selected) !important;
      }

      .container-3wLKDe {
        background-color: var(--background-secondary) !important;
      }

      .title-31SJ6t {
        background-color: var(--background-primary) !important;
      }

      .scrollableContainer__33e06.themedBackground__6b1b6.webkit__8d35a {
        background-color: #${base00};
      }
      .autocomplete_df266d .autocompleteInner_a0e6a1 .input__848cd {
        background-color: #${base00};
      }
    '';
  };

}

{
  pkgs,
  inputs,
  config,
  ...
}: {
  # ========================== unfinished ========================== #
  # home.file."telegramtest".text = with config.colorScheme.colors; ''
  #   color0='#${base00}'
  #   color1='#${base08}'
  #   color2='#${base0B}'
  #   color3='#${base0A}'
  #   color4='#${base0D}'
  #   color5='#${base0E}'
  #   color6='#${base0C}'
  #   color7='#${base07}'
  #   color8='#${base02}'
  #   color9='#${base08}'
  #   color10='#${base0B}'
  #   color11='#${base0A}'
  #   color12='#${base0D}'
  #   color13='#${base01}'
  #   color14='#${base0D}'
  #   color15='#${base07}'
  # '';

  myHomeManager.impermanence.directories = [
    ".local/share/TelegramDesktop"
  ];
}

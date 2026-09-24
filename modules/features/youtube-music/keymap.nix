{
  keymap = {
    binds."SUPER,p" = {
      desc = "Play/pause";
      cmd = {pkgs, ...}: "${pkgs.playerctl}/bin/playerctl play-pause";
    };

    mouse."SUPER,btn_middle" = {
      desc = "Music";
      cmd = {vjshell, ...}: "${vjshell} ipc call music toggle";
    };

    menu.m = {
      desc = "Music";
      icon = "music_note";
      order = 24;
      action = "music.toggle";
    };
  };
}

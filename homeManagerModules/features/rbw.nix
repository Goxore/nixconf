{
  pkgs,
  inputs,
  config,
  ...
}: {
  programs.rbw = {
    enable = true;
    settings = {
      email = "yurii@goxore.com";
      # lock_timeout = 300;
      pinentry = "curses";
    };
  };
}

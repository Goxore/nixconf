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
      base_url = "https://api.bitwarden.com/";
      identity_url = "https://identity.bitwarden.com/";
      lock_timeout = 300;
      pinentry = pkgs.pinentry-curses;
    };
  };
}

{
  inputs,
  pkgs,
  ...
}: {
  programs.fish = {
    enable = true;

    functions = {
      fish_prompt = {
        body = ''
          string join "" -- (set_color red) "[" (set_color yellow) $USER (set_color green) "@" (set_color blue) $hostname (set_color magenta) " " $PWD (set_color red) ']' (set_color normal) "\$ "
        '';
      };

      # lfcd = {
      #   body = ''
      #     cd "$(command lf -print-last-dir $argv)"
      #   '';
      # };

      hst = {
        body = ''
          history | uniq | ${pkgs.fzf}/bin/fzf | ${pkgs.wl-clipboard}/bin/wl-copy -n
        '';
      };
    };

    shellInit = ''
      set fish_greeting

      set -x EDITOR nvim

    '';

    shellAliases = {
      lf = "lfcd";
      os = "nh os";
    };

    # setup vi mode
    interactiveShellInit = ''
      fish_vi_key_bindings
    '';
  };

  myHomeManager.impermanence.cache.directories = [
    ".local/share/fish"
  ];
}

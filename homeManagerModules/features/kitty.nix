{
  pkgs,
  config,
  ...
}: {
  programs.kitty = {
    enable = true;
    # keybindings = {
    #   "kitty_mod+h" = "neighboring_window left";
    #   "kitty_mod+l" = "neighboring_window right";
    #   "kitty_mod+j" = "neighboring_window down";
    #   "kitty_mod+k" = "neighboring_window up";
    # };
    shellIntegration.enableZshIntegration = true;
    settings = {
      enable_audio_bell = "no";

      # cursor = "#${base06}";
      cursor_text_color = "background";

      # scrollback_pager = ''nvim -c "set signcolumn=no showtabline=0" -c "silent write! /tmp/kitty_scrollback_buffer | te cat /tmp/kitty_scrollback_buffer - "'';

      allow_remote_control = "yes";
      listen_on = "unix:/tmp/kitty";
      shell_integration = "enabled";
    };
    extraConfig = ''
      # GENERATED
      action_alias kitty_scrollback_nvim kitten /home/${config.home.username}/.local/share/nvim/lazy/kitty-scrollback.nvim/python/kitty_scrollback_nvim.py
      map kitty_mod+h kitty_scrollback_nvim
      map kitty_mod+g kitty_scrollback_nvim --config ksb_builtin_last_cmd_output
      mouse_map ctrl+shift+right press ungrabbed combine : mouse_select_command_output : kitty_scrollback_nvim --config ksb_builtin_last_visited_cmd_output
    '';
  };
}

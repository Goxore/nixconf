{
  wrappers.tmux = {wlib, ...}: {
    imports = [wlib.wrapperModules.tmux];

    terminal = "screen-256color";
    historyLimit = 50000;

    configAfter = ''
      set -g status off
      set -ga terminal-features "*:RGB"
    '';
  };
}

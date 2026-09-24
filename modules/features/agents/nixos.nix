{
  modules.nixos.base = {
    persistence.data.directories = [
      ".local/share/claude-per"
      ".local/share/claude-fish"
      ".local/share/codex"
      ".local/share/opencode"
    ];
  };
}

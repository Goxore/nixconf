{
  modules.nixos.base = {
    persistence.cache.directories = [
      ".config/nvim"
      ".local/share/nvim"
      ".local/state/nvim"
    ];
  };
}

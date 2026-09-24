{
  modules.nixos.base = {
    persistence.cache.directories = [
      ".local/share/fish"
      ".local/share/zoxide"
    ];
  };
}

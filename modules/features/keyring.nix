{
  modules.nixos.desktop = {
    services.gnome.gnome-keyring.enable = true;

    persistence.data.directories = [
      ".local/share/keyrings"
    ];
  };
}

{
  modules.nixos.desktop = {
    config,
    pkgs,
    ...
  }: {
    hjem.users.${config.preferences.user.name}.files.".config/xdg-desktop-portal-wlr/config".text = ''
      [screencast]
      chooser_type=dmenu
      chooser_cmd=${pkgs.vj.vjSharePicker}/bin/vjSharePicker
    '';
  };
}

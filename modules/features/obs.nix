{
  modules.nixos.obs = {pkgs, ...}: {
    programs.obs-studio = {
      enable = true;
      plugins = [
        (pkgs.obs-studio-plugins.obs-move-transition.overrideAttrs (previous: {
          env = (previous.env or {}) // {NIX_CFLAGS_COMPILE = "-Wno-error=deprecated-declarations";};
        }))
      ];
    };

    persistence.cache.directories = [
      ".config/obs-studio"
    ];
  };
}

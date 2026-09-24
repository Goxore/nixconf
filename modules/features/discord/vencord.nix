{
  packages = pkgs: {
    vencord = pkgs.vencord.overrideAttrs (previous: {
      postPatch =
        previous.postPatch
        + ''
          mkdir -p src/userplugins
          cp -r ${./call-rail} src/userplugins/callRail
          chmod -R u+w src/userplugins/callRail
        '';
    });
  };
}

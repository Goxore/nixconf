c: let
  normalize = value:
    if builtins.isString value || builtins.isPath value || (builtins.isAttrs value && (value.type or null) == "derivation")
    then builtins.concatStringsSep "" (builtins.filter builtins.isString (builtins.split "/nix/store/[0-9a-z]{32}-" (builtins.unsafeDiscardStringContext (toString value))))
    else if builtins.isList value
    then map normalize value
    else if builtins.isAttrs value
    then builtins.mapAttrs (_: normalize) value
    else value;
  sortS = xs: builtins.sort (a: b: a < b) xs;
  uniqS = xs:
    builtins.attrNames (builtins.listToAttrs (map (x: {
        name = x;
        value = null;
      })
      xs));
  names = ps: sortS (map (p: normalize (toString p)) ps);
  select = fields: value:
    builtins.intersectAttrs (builtins.listToAttrs (map (name: {
        inherit name;
        value = null;
      })
      fields))
    value;
  units = fields: builtins.mapAttrs (_: unit: normalize (select (["enable" "wantedBy" "requiredBy" "wants" "requires" "after" "before" "partOf" "unitConfig"] ++ fields) unit));
  services = units ["environment" "serviceConfig" "script" "preStart" "postStart" "preStop" "postStop" "reload" "path" "restartIfChanged" "reloadIfChanged" "stopIfChanged"];
  scope = e: {
    dirs = map (d: normalize (select ["directory" "user" "group" "mode"] d)) (e.directories or []);
    files = map (f: normalize (select ["file" "parentDirectory"] f)) (e.files or []);
  };
in {
  systemPackages = names c.environment.systemPackages;
  systemPackagesUnique = uniqS (names c.environment.systemPackages);
  etc = builtins.attrNames c.environment.etc;
  persistence = builtins.mapAttrs (_: e: {
    system = scope e;
    users = builtins.mapAttrs (_: scope) (e.users or {});
  }) (c.environment.persistence or {});
  systemdServices = services c.systemd.services;
  systemdUser = services c.systemd.user.services;
  systemdTimers = units ["timerConfig"] c.systemd.timers;
  users = builtins.attrNames c.users.users;
  userShells = builtins.mapAttrs (_: u: normalize (toString u.shell)) c.users.users;
  fonts = names c.fonts.packages;
  defaultFonts = c.fonts.fontconfig.defaultFonts;
  consoleColors = c.console.colors;
  timeZone = c.time.timeZone;
  locale = c.i18n.extraLocaleSettings;
  kernelModules = c.boot.kernelModules;
  kernelParams = c.boot.kernelParams;
  initrdModules = c.boot.initrd.kernelModules;
  initrdAvailable = c.boot.initrd.availableKernelModules;
  blacklisted = c.boot.blacklistedKernelModules;
  hostName = c.networking.hostName;
  firewall = normalize (select ["enable" "allowedUDPPorts" "allowedTCPPorts" "allowedUDPPortRanges" "allowedTCPPortRanges" "interfaces" "trustedInterfaces" "checkReversePath" "filterForward" "extraCommands" "extraStopCommands" "extraInputRules" "extraForwardRules" "extraReversePathFilterRules"] c.networking.firewall);
  stateVersion = c.system.stateVersion;
  hjemFiles = builtins.mapAttrs (_: u: builtins.attrNames u.files) (c.hjem.users or {});
  xdgPortal = c.xdg.portal.enable;
  xdgPortals = names c.xdg.portal.extraPortals;
  nixSettings = c.nix.settings;
}

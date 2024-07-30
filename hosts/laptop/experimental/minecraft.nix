{
  stdenvNoCC,
  cacert,
  curl,
  runCommandNoCC,
  jdk,
  version ? throw "Minecraft server version must be specified",
  hash ? throw "Minecraft server hash must be specified",
}:
stdenvNoCC.mkDerivation {
  pname = "minecraft-server";
  version = "forge-${version}";
  meta.mainProgram = "server";

  dontUnpack = true;
  dontConfigure = true;

  src =
    runCommandNoCC "forge-${version}"
    {
      inherit version;
      nativeBuildInputs = [
        cacert
        curl
        jdk
      ];

      outputHashMode = "recursive";
      outputHash = hash;
    }
    ''
      mkdir -p "$out"

      curl "https://maven.minecraftforge.net/net/minecraftforge/forge/${version}/forge-${version}-installer.jar" -o ./installer.jar
      java -jar ./installer.jar --installServer "$out"
    '';

  buildPhase = ''
    mkdir -p $out/bin

    cp "$src/libraries/net/minecraftforge/forge/${version}/unix_args.txt" "$out/bin/unix_args.txt"
  '';

  installPhase = ''
    cat <<\EOF >>$out/bin/server
    ${jdk}/bin/java "$@" "@${builtins.placeholder "out"}/bin/unix_args.txt" nogui
    EOF

    chmod +x $out/bin/server
  '';

  # substituteInPlace $out/bin/unix_args.txt \
  #   --replace-fail "libraries" "$src/libraries"

  fixupPhase = ''
    substituteInPlace $out/bin/unix_args.txt \
      --replace-fail "forge-${version}-shim.jar" "$src/forge-${version}-shim.jar"
  '';
}

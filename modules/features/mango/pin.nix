{inputs, ...}: {
  nixpkgsOverlays = [
    (_: prev: {
      mango = prev.mango.overrideAttrs (_: {
        version = "0.17.3";
        src = inputs.mango;
        patches = [./mango-istaganchor.patch];
      });
    })
  ];
}

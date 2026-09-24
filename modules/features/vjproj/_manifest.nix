material:
builtins.toJSON {
  name = "vjproj";
  short_name = "vjproj";
  id = "/";
  start_url = "/";
  scope = "/";
  display = "standalone";
  background_color = material.surface;
  theme_color = material.surface;
  icons = [
    {
      src = "icon-192.png";
      sizes = "192x192";
      type = "image/png";
      purpose = "any";
    }
    {
      src = "icon-512.png";
      sizes = "512x512";
      type = "image/png";
      purpose = "any";
    }
    {
      src = "icon-mask.png";
      sizes = "512x512";
      type = "image/png";
      purpose = "maskable";
    }
  ];
}

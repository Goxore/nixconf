{
  modules.nixos.base = {
    persistence.data.directories = [
      "nixconf"

      "Videos"
      "NewVideos"
      "Documents"
      "Projects"

      ".ssh"
    ];
  };
}

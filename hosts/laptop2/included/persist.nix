{...}: {
  myNixOS = {
    impermanence.enable = true;
    impermanence.nukeRoot.enable = true;
  };

  environment.persistence."/persist/home/yurii".users."yurii" = {
    directories = [
      "Downloads"
      "Music"
      "Pictures"
      "Projects"
      "Documents"
      "Videos"
      ".gnupg"
      ".ssh"
      ".nixops"
      ".config/dconf"
      ".local/share/keyrings"
      ".local/share/direnv"

      "nixconf"

      ".mozilla"
      ".cache/mozilla"

      ".local/share/Steam"
      ".config/r2modmanPlus-local"

      ".config/VencordDesktop"

      ".local/share/TelegramDesktop"

      ".local/share/nvim"
      ".config/nvim"
    ];
    files = [
      ".zsh_history"
    ];
  };
}

{pkgs, ...}: {
  hardware.uinput.enable = true;
  users.groups.uinput.members = ["yurii"];
  users.groups.input.members = ["yurii"];
}

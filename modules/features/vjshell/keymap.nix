{
  keymap.menu = let
    toggle = order: target: {
      inherit order;
      action = "${target}.toggle";
    };
  in {
    Tab = {
      order = 5;
      desc = "New project";
      icon = "add_box";
      action = "projects.create";
    };
    b =
      toggle 10 "bluetooth"
      // {
        desc = "Bluetooth";
        icon = "bluetooth";
      };
    w =
      toggle 11 "wifi"
      // {
        desc = "Wi-Fi";
        icon = "wifi";
      };
    x =
      toggle 12 "processes"
      // {
        desc = "Processes";
        icon = "monitor_heart";
      };
    r =
      toggle 13 "vr"
      // {
        desc = "VR";
        icon = "head_mounted_device";
      };
    n =
      toggle 14 "notifications"
      // {
        desc = "Notifications";
        icon = "notifications";
      };
    v =
      toggle 15 "recorder"
      // {
        desc = "Record screen";
        icon = "screen_record";
      };
  };
}

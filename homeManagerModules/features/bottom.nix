{pkgs, ...}: {
  programs.bottom = {
    enable = true;
    settings = {
      flags = {};
      row = [
        {child = [{type = "cpu";}];}
        {
          ratio = 2;
          child = [
            {
              ratio = 4;
              child = [
                {
                  ratio = 3;
                  type = "mem";
                }
                {
                  ratio = 5;
                  type = "net";
                }
              ];
            }
            {
              ratio = 3;
              child = [
                {
                  default = true;
                  type = "proc";
                }
              ];
            }
          ];
        }
      ];
    };
  };
}

{
  flake.nixosModules.pipewire = {pkgs, ...}: {
    preferences.keymap = {
      "SUPER + v".exec = ''${pkgs.alsa-utils}/bin/amixer sset Capture toggle'';
      "SUPER + d"."s".package = pkgs.pwvucontrol;
    };

    persistance.cache.directories = [
      ".local/state/wireplumber"
    ];

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;

      extraConfig = {
        # cooler denoising
        pipewire."99-input-denoising" = {
          "context.modules" = [
            {
              "name" = "libpipewire-module-filter-chain";
              "args" = {
                "node.description" = "DeepFilter Noise Cancelling Source";
                "media.name" = "DeepFilter Noise Cancelling Source";
                "filter.graph" = {
                  "nodes" = [
                    {
                      "type" = "ladspa";
                      "name" = "DeepFilter Mono";
                      "plugin" = "${pkgs.deepfilternet}/lib/ladspa/libdeep_filter_ladspa.so";
                      "label" = "deep_filter_mono";
                      # "control" = {
                      #   "Attenuation Limit (dB)" = cfg.source.attenuation;
                      # };
                    }
                  ];
                };
                "audio.rate" = 48000;
                "capture.props" = {
                  "node.name" = "deep_filter_mono_input";
                  "node.passive" = true;
                };
                "playback.props" = {
                  "node.name" = "deep_filter_mono_output";
                  "media.class" = "Audio/Source";
                };
              };
            }
          ];
        };

        # https://discourse.nixos.org/t/pipewire-rnnoise-module-wont-work/58975/12
        # pipewire."99-input-denoising" = {
        #   "context.modules" = [
        #     {
        #       name = "libpipewire-module-filter-chain";
        #       args = {
        #         "node.description" = "Noise Canceling source";
        #         "media.name" = "Noise Canceling source";
        #         "filter.graph" = {
        #           nodes = [
        #             {
        #               type = "ladspa";
        #               name = "rnnoise";
        #               plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
        #               label = "noise_suppressor_mono";
        #               control = {
        #                 "VAD Threshold (%)" = 50.0;
        #                 "VAD Grace Period (ms)" = 200;
        #                 "Retroactive VAD Grace (ms)" = 0;
        #               };
        #             }
        #           ];
        #         };
        #         "capture.props" = {
        #           "node.name" = "capture.rnnoise_source";
        #           "node.passive" = true;
        #           "audio.rate" = 48000;
        #         };
        #         "playback.props" = {
        #           "node.name" = "rnnoise_source";
        #           "media.class" = "Audio/Source";
        #           "audio.rate" = 48000;
        #         };
        #       };
        #     }
        #   ];
        # };
      };
    };
  };
}

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

      configPackages = [pkgs.deepfilternet];
      extraLadspaPackages = [pkgs.deepfilternet];
      extraConfig = {
        pipewire = {
          "90-defaults" = {
            "context.properties" = {
              "clock.power-of-two-quantum" = true;
              "core.daemon" = true;
              "core.name" = "pipewire-0";
              "link.max-buffers" = 16;
              "settings.check-quantum" = true;

              "default.clock.rate" = 96000;
              "default.clock.allowed-rates" = [44100 48000 88200 96000 192000 352800 384000];
              "default.clock.quantum" = 256;
              "default.clock.min-quantum" = 32;
              "default.clock.max-quantum" = 4096;
            };
            "stream.properties" = {
              "resample.quality" = 10;
            };
          };

          "90-disable-bell" = {
            "context.properties" = {
              "module.x11.bell" = false;
            };
          };
        };

        pipewire-pulse = {
          "90-defaults" = {
            "context.spa-libs" = {
              "audio.convert.*" = "audioconvert/libspa-audioconvert";
              "support.*" = "support/libspa-support";
            };

            "stream.properties" = {
              "resample.quality" = 10;
            };

            "pulse.properties" = {
              "server.address" = ["unix:native"];
            };
          };
        };

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
                      "plugin" = "libdeep_filter_ladspa";
                      "label" = "deep_filter_mono";
                      "control" = {
                        "Attenuation Limit (dB)" = 100;
                      };
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

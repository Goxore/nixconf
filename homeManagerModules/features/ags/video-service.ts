// https://aylur.github.io/ags-docs/config/custom-service/

class VideoService extends Service {
    // every subclass of GObject.Object has to register itself
    static {
        // takes three arguments
        // the class itself
        // an object defining the signals
        // an object defining its properties
        Service.register(
            this,
            {
                // 'name-of-signal': [type as a string from GObject.TYPE_<type>],
                'recording-changed': ['float'],
            },
            {
                // 'kebab-cased-name': [type as a string from GObject.TYPE_<type>, 'r' | 'w' | 'rw']
                // 'r' means readable
                // 'w' means writable
                // guess what 'rw' means
                'recording-value': ['float', 'rw'],
            },
        );
    }

    // this Service assumes only one device with backlight
    //#interface = Utils.exec("sh -c 'ls -w1 /sys/class/backlight | head -1'");

    // # prefix means private in JS
    #recordingValue = 0;
    //#max = Number(Utils.exec('brightnessctl max'));

    // the getter has to be in snake_case
    get recording_value() {
        return this.#recordingValue;
    }

    // the setter has to be in snake_case too
    set recording_value(percent) {
        //if (percent < 0)
        //    percent = 0;
        //
        //if (percent > 1)
        //    percent = 1;
        //
        //Utils.execAsync(`brightnessctl set ${percent * 100}% -q`);
    }

    constructor() {
        super();

        // setup monitor
        const brightness = `/tmp/recording-value`;
        Utils.monitorFile(brightness, () => this.#onChange());

        // initialize
        this.#onChange();
    }

    #onChange() {
        let result = Number(Utils.exec(`cat /tmp/recording-value`));
        result = isNaN(result) ? 0 : result;
        this.#recordingValue = result;

        // signals have to be explicitly emitted
        this.emit('changed'); // emits "changed"
        this.notify('recording-value'); // emits "notify::recording-value"

        // or use Service.changed(propName: string) which does the above two
        // this.changed('recording-value');

        // emit recording-changed with the percent as a parameter
        this.emit('recording-changed', this.#recordingValue);
    }

    // overwriting the connect method, let's you
    // change the default event that widgets connect to
    connect(event = 'recording-changed', callback) {
        return super.connect(event, callback);
    }
}

// the singleton instance
const service = new VideoService;

// export to use in other modules
export default service;

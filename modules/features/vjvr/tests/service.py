import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time
import asyncio
import threading
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, dbus_property
from dbus_next.constants import PropertyAccess

binary = str(Path(sys.argv[1]).resolve())


def wait_until(check, seconds=8):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = check()
        if value:
            return value
        time.sleep(0.03)
    raise AssertionError('condition timed out')


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    bindir = root / 'bin'
    bindir.mkdir()
    fixture = root / 'fixture.json'
    fixture.write_text(json.dumps({'mode': 'ready', 'worn': False, 'connected': False}))
    audio = root / 'audio.json'
    audio.write_text(json.dumps({'sink': 'desktop', 'source': 'microphone', 'stream': 'desktop', 'capture': 'microphone'}))
    bus_ready = threading.Event()

    class Runtime(ServiceInterface):
        def __init__(self):
            super().__init__('io.github.wivrn.Server')

        @dbus_property(access=PropertyAccess.READ)
        def HeadsetConnected(self) -> 'b':
            return json.loads(fixture.read_text()).get('connected', False)

        @dbus_property(access=PropertyAccess.READ)
        def SessionRunning(self) -> 'b':
            return self.HeadsetConnected

        @dbus_property(access=PropertyAccess.READ)
        def SystemName(self) -> 's':
            return 'Meta Quest 3'

        @dbus_property(access=PropertyAccess.READ)
        def Bitrate(self) -> 'u':
            return 50000000

        @dbus_property(access=PropertyAccess.READ)
        def PreferredRefreshRate(self) -> 'd':
            return 90.0

        @dbus_property(access=PropertyAccess.READ)
        def SupportedCodecs(self) -> 'as':
            return ['h264', 'h265']

        @dbus_property(access=PropertyAccess.READ)
        def PairingEnabled(self) -> 'b':
            return False

        @dbus_property(access=PropertyAccess.READ)
        def Pin(self) -> 's':
            return ''

        @dbus_property(access=PropertyAccess.READ)
        def JsonConfiguration(self) -> 's':
            return '{}'

    async def serve_runtime():
        bus = await MessageBus().connect()
        bus.export('/io/github/wivrn/Server', Runtime())
        await bus.request_name('io.github.wivrn.Server')
        bus_ready.set()
        await asyncio.Future()

    threading.Thread(target=lambda: asyncio.run(serve_runtime()), daemon=True).start()
    assert bus_ready.wait(5)
    mock = bindir / 'mock'
    mock.write_text('#!' + sys.executable + '\n' + '''import json, os, shlex, sys, time
from pathlib import Path
fixture = json.loads(Path(os.environ['VJVR_TEST_FIXTURE']).read_text())
mode = fixture['mode']
name = Path(sys.argv[0]).name
args = sys.argv[1:]
if name == 'adb':
    if args[0] == 'devices':
        print('List of devices attached')
        if mode == 'moved':
            if not fixture.get('old_disconnected'): print('192.168.1.2:5555 device product:eureka model:Quest_3')
            if fixture.get('connected_new'): print('192.168.12.193:5555 device product:eureka model:Quest_3')
        elif mode != 'offline': print('192.168.1.2:5555 device product:eureka model:Quest_3')
    elif args[0] == 'connect':
        if mode == 'moved' and args[1] == '192.168.1.2:5555': sys.exit(1)
        if mode == 'moved' and args[1] == '192.168.12.193:5555':
            fixture['connected_new'] = True
            Path(os.environ['VJVR_TEST_FIXTURE']).write_text(json.dumps(fixture))
        print('connected to ' + args[1])
    elif args[0] == 'disconnect':
        if mode == 'moved' and args[1] == '192.168.1.2:5555':
            fixture['old_disconnected'] = True
            Path(os.environ['VJVR_TEST_FIXTURE']).write_text(json.dumps(fixture))
    elif args[2] == 'shell':
        if mode == 'offline' or mode == 'moved' and args[1] == '192.168.1.2:5555': sys.exit(1)
        remote = shlex.split(args[3])
        if mode == 'slow': time.sleep(30)
        if remote == ['getprop']:
            print('[ro.product.model]: [Quest 3]\\n[ro.serialno]: [test-quest]\\n[ro.build.version.release]: [14]')
        elif remote[:2] == ['dumpsys', 'package']:
            print('Package [org.meumeu.wivrn.github] (1):\\n versionCode=1 minSdk=29\\n versionName=26.9')
        elif remote[:3] == ['pm', 'list', 'packages']: print('package:org.meumeu.wivrn.github')
        elif remote[:2] == ['dumpsys', 'battery']: print('level: 86\\nstatus: 3')
        elif remote[0] == 'df': print('Filesystem 1K-blocks Used Available Use% Mounted on\\n/data 1000 400 600 40% /data')
        elif remote[0] == 'ip':
            address = '192.168.12.193' if mode == 'moved' and args[1] == '192.168.12.193:5555' else '192.168.1.2'
            print('2: wlan0 inet ' + address + '/24 scope global wlan0')
        elif remote[:2] == ['getprop', 'ro.serialno']: print('test-quest')
        elif remote == ['dumpsys', 'vrpowermanager']:
            print('Virtual proximity state: DISABLED\\nMountWakeLock count: 0\\nState: ' + ('HEADSET_MOUNTED' if fixture.get('worn') else 'HEADSET_UNMOUNTED'))
elif name == 'systemctl':
    if 'is-active' in args: print('inactive'); sys.exit(3)
    if 'show' in args: print('0')
    if 'start' in args and 'vjvr-desktop.service' not in args: time.sleep(30)
elif name == 'ip': print('[]')
elif name == 'iw': sys.exit(1)
elif name == 'avahi-browse':
    if mode == 'moved': print('=;ap0;IPv4;quest;_adb._tcp;local;Android.local;192.168.12.193;5555;')
elif name == 'pactl':
    path = Path(os.environ['VJVR_TEST_AUDIO'])
    audio = json.loads(path.read_text())
    if args[:2] == ['--format=json', 'info']:
        print(json.dumps({'default_sink_name': audio['sink'], 'default_source_name': audio['source']}))
    elif args[:2] == ['--format=json', 'list']:
        if args[2] == 'sinks': print(json.dumps([{'name': 'desktop', 'index': 1}, {'name': 'wivrn.sink', 'index': 2}]))
        elif args[2] == 'sources': print(json.dumps([{'name': 'microphone', 'index': 3}, {'name': 'wivrn.sink.monitor', 'index': 4}, {'name': 'wivrn.source', 'index': 5}]))
        elif args[2] == 'sink-inputs': print(json.dumps([{'index': 10, 'sink': 1 if audio['stream'] == 'desktop' else 2, 'properties': {'application.name': 'Game'}}]))
        elif args[2] == 'source-outputs': print(json.dumps([{'index': 11, 'source': 3 if audio['capture'] == 'microphone' else 5, 'properties': {'application.name': 'Voice chat'}}]))
        else: print('[]')
    else:
        if args[0] == 'set-default-sink': audio['sink'] = args[1]
        elif args[0] == 'set-default-source': audio['source'] = args[1]
        elif args[0] == 'move-sink-input': audio['stream'] = args[2]
        elif args[0] == 'move-source-output': audio['capture'] = args[2]
        path.write_text(json.dumps(audio))
''')
    mock.chmod(0o700)
    for name in ['adb', 'systemctl', 'ip', 'iw', 'avahi-browse', 'pactl']:
        (bindir / name).symlink_to(mock)
    config = root / 'config.json'
    config.write_text(json.dumps({
        'server_version': '26.9', 'apk': '/unused', 'apk_sha256': '',
        'apk_package': 'org.meumeu.wivrn.github', 'hotspot_unit': 'create_ap.service',
        'hotspot_interface': 'ap0', 'hotspot_passphrase': '/unused', 'wifi_interface': 'wlan0', 'hostname': 'test',
        'preview_command': '/unused', 'desktop_command': '/unused',
    }))
    env = dict(os.environ, XDG_RUNTIME_DIR=str(root), XDG_STATE_HOME=str(root / 'state'),
               PATH=str(bindir) + os.pathsep + os.environ['PATH'], VJVR_TEST_FIXTURE=str(fixture), VJVR_TEST_AUDIO=str(audio))
    control = root / 'vjvr/control.sock'

    def request(action):
        with socket.socket(socket.AF_UNIX) as stream:
            stream.settimeout(3)
            stream.connect(str(control))
            stream.sendall(json.dumps(action).encode() + b'\n')
            return json.loads(stream.makefile('rb').readline())

    def state():
        return request({'action': 'status'})['data']

    def complete():
        current = state()
        return current if not current['operation']['running'] else None

    process = subprocess.Popen([binary, 'serve', '--config', str(config)], env=env)
    try:
        wait_until(control.exists)
        assert control.stat().st_mode & 0o777 == 0o600
        current = wait_until(lambda: state() if state()['selected'] else None)
        wait_until(lambda: state()['headsets'][0]['inventory_time'])
        current = state()
        assert current['headsets'][0]['software'][0]['version'] == '26.9'
        assert not current['runtime']['connected']
        assert current['preferences']['open_desktop']
        assert request({'action': 'refresh'})['ok']
        assert not wait_until(complete)['operation']['error']
        fixture.write_text(json.dumps({'mode': 'slow'}))
        assert request({'action': 'refresh'})['ok']
        assert request({'action': 'refresh'})['error'] == 'busy'
        started = time.monotonic()
        assert request({'action': 'cancel'})['ok']
        assert wait_until(complete)['operation']['error'] == 'cancelled'
        assert time.monotonic() - started < 2
        fixture.write_text(json.dumps({'mode': 'offline'}))
        assert request({'action': 'refresh'})['ok']
        current = wait_until(complete)
        assert current['headsets'][0]['status'] == 'offline'
        assert current['headsets'][0]['software'][0]['version'] == '26.9'
        saved_path = root / 'state/vjvr/state.json'
        saved = json.loads(saved_path.read_text())
        assert saved['wireless'][0]['serial'] == 'test-quest'
        assert not saved['interrupted']
        saved_path.unlink()
        saved_path.mkdir()
        assert request({'action': 'refresh'})['error'] == 'save_failed'
        assert not state()['operation']['running']
        saved_path.rmdir()
        assert request({'action': 'preferences', 'preferences': {
            'start_hotspot': False, 'open_desktop': True, 'headset_audio': False}})['ok']
        assert wait_until(complete)['preferences']['start_hotspot'] is False
        assert not state()['preferences']['auto_connect']
        fixture.write_text(json.dumps({'mode': 'ready', 'worn': False, 'connected': True}))
        assert request({'action': 'preferences', 'preferences': {
            'start_hotspot': False, 'open_desktop': True, 'headset_audio': True}})['ok']
        wait_until(complete)
        wait_until(lambda: state()['worn'] is False and state()['runtime']['connected'])
        assert json.loads(audio.read_text())['sink'] == 'desktop'
        fixture.write_text(json.dumps({'mode': 'ready', 'worn': True, 'connected': True}))
        wait_until(lambda: state()['session']['audio_routed'])
        assert json.loads(audio.read_text()) == {'sink': 'wivrn.sink', 'source': 'wivrn.source', 'stream': 'wivrn.sink', 'capture': 'wivrn.source'}
        fixture.write_text(json.dumps({'mode': 'ready', 'worn': False, 'connected': True}))
        wait_until(lambda: not state()['session']['audio_routed'])
        assert json.loads(audio.read_text()) == {'sink': 'desktop', 'source': 'microphone', 'stream': 'desktop', 'capture': 'microphone'}
        assert state()['runtime']['connected']
        assert request({'action': 'preferences', 'preferences': {
            'auto_connect': True, 'start_hotspot': False, 'open_desktop': True, 'headset_audio': True}})['ok']
        wait_until(complete)
        wait_until(lambda: state()['session']['started_desktop'])
        assert request({'action': 'preferences', 'preferences': {
            'auto_connect': False, 'start_hotspot': False, 'open_desktop': True, 'headset_audio': True}})['ok']
        wait_until(complete)
        fixture.write_text(json.dumps({'mode': 'ready', 'worn': True, 'connected': True}))
        wait_until(lambda: state()['session']['audio_routed'])
        fixture.write_text(json.dumps({'mode': 'offline', 'connected': False}))
        wait_until(lambda: not state()['session']['audio_routed'])
        assert json.loads(audio.read_text())['sink'] == 'desktop'
        fixture.write_text(json.dumps({'mode': 'ready', 'worn': False, 'connected': False}))
        assert request({'action': 'refresh'})['ok']
        wait_until(complete)
        wait_until(lambda: state()['worn'] is False)
        assert request({'action': 'preferences', 'preferences': {
            'auto_connect': True, 'start_hotspot': False, 'open_desktop': True, 'headset_audio': True}})['ok']
        wait_until(complete)
        assert state()['operation']['action'] == 'preferences'
        fixture.write_text(json.dumps({'mode': 'ready', 'worn': True, 'connected': False}))
        wait_until(lambda: state()['operation']['action'] == 'start' and state()['operation']['running'])
        assert request({'action': 'cancel'})['ok']
        assert not wait_until(complete)['preferences']['auto_connect']
        assert request({'action': 'stop'})['ok']
        assert not wait_until(complete)['preferences']['auto_connect']
        fixture.write_text(json.dumps({'mode': 'moved', 'connected_new': False, 'old_disconnected': False}))
        assert request({'action': 'refresh'})['ok']
        current = wait_until(complete)
        assert current['headsets'][0]['endpoint'] == '192.168.12.193:5555'
        assert json.loads(saved_path.read_text())['wireless'][0]['address'] == '192.168.12.193'
        assert json.loads(fixture.read_text())['old_disconnected']
    finally:
        process.send_signal(signal.SIGINT)
        process.wait(timeout=5)
    assert not control.exists()
    print('PASS inventory, cancellation, persistence, wear audio, stream migration, disconnect recovery, wireless rediscovery, and autoconnect')

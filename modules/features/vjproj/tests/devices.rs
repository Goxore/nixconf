use std::collections::HashMap;
use vjproj::devices::{self, Battery, Charge, Device, Kind, Known, System};
use vjproj::tailnet::{self, Sighting};

const STATUS: &str = r#"{
  "Self": {
    "HostName": "main",
    "DNSName": "main.example.ts.net.",
    "OS": "linux",
    "UserID": 2,
    "Online": true,
    "LastSeen": "0001-01-01T00:00:00Z"
  },
  "Peer": {
    "nodekey:aaa": {
      "HostName": "Pixel 8a",
      "DNSName": "pixel-8a.example.ts.net.",
      "OS": "android",
      "UserID": 2,
      "Online": false,
      "LastSeen": "2026-09-24T10:30:00Z"
    },
    "nodekey:bbb": {
      "HostName": "someone-else",
      "DNSName": "someone-else.example.ts.net.",
      "OS": "linux",
      "UserID": 1,
      "Online": true
    }
  }
}"#;

const VJVR: &str = r#"{
  "selected": "TESTSERIAL",
  "headsets": [
    {
      "serial": "OTHER",
      "model": "Quest 2",
      "status": "offline",
      "battery": 10,
      "charging": false,
      "android": "12",
      "software": [],
      "last_seen": 100
    },
    {
      "serial": "TESTSERIAL",
      "model": "Quest 3",
      "status": "device",
      "battery": 64,
      "charging": true,
      "android": "14",
      "software": [
        {"package": "com.example.game", "version": "1.0"},
        {"package": "org.meumeu.wivrn.github", "version": "26.9"}
      ],
      "last_seen": 1790000000
    }
  ]
}"#;

fn machines(names: &[&str]) -> Vec<String> {
    names.iter().map(|name| (*name).to_owned()).collect()
}

fn system(revision: &str) -> System {
    System {
        release: "26.11".into(),
        revision: Some(revision.into()),
        built: Some(1_790_000_000),
    }
}

fn sighting(id: &str, os: &str, online: bool, here: bool) -> Sighting {
    Sighting {
        id: id.into(),
        name: id.into(),
        os: os.into(),
        online,
        seen: Some(1_789_000_000),
        here,
    }
}

fn found<'a>(devices: &'a [Device], id: &str) -> &'a Device {
    devices.iter().find(|device| device.id == id).unwrap()
}

#[test]
fn tailscale_timestamps_become_unix_seconds() {
    assert_eq!(tailnet::unix_seconds("1970-01-01T00:00:01Z"), Some(1));
    assert_eq!(
        tailnet::unix_seconds("2026-09-24T10:30:00Z"),
        Some(1_790_245_800)
    );
    assert_eq!(
        tailnet::unix_seconds("2024-02-29T23:59:59.123456Z"),
        Some(1_709_251_199)
    );
    assert_eq!(tailnet::unix_seconds("0001-01-01T00:00:00Z"), None);
    assert_eq!(tailnet::unix_seconds("2026-13-01T00:00:00Z"), None);
    assert_eq!(tailnet::unix_seconds("2026-09-24T10:30:00+03:00"), None);
    assert_eq!(tailnet::unix_seconds(""), None);
}

#[test]
fn sightings_cover_this_machine_and_every_device_of_the_same_user() {
    let seen = tailnet::parse_sightings(STATUS);
    let ids: Vec<&str> = seen.iter().map(|sighting| sighting.id.as_str()).collect();
    assert_eq!(ids, ["main", "pixel-8a"]);

    let main = &seen[0];
    assert!(main.here && main.online);
    assert_eq!(main.seen, None);

    let phone = &seen[1];
    assert_eq!(phone.name, "Pixel 8a");
    assert_eq!(phone.os, "android");
    assert!(!phone.online);
    assert_eq!(phone.seen, Some(1_790_245_800));

    assert!(tailnet::parse_sightings("not json").is_empty());
}

#[test]
fn a_charging_battery_estimates_when_it_will_be_full() {
    let plugged = Battery::reported(None, 40, true, 1_000);
    assert_eq!(
        plugged.since,
        Some(Charge {
            level: 40,
            at: 1_000
        })
    );
    assert_eq!(plugged.full_at, None, "one sample cannot give a rate");

    let later = Battery::reported(Some(&plugged), 50, true, 1_600);
    assert_eq!(
        later.since, plugged.since,
        "the charge keeps its starting point"
    );
    assert_eq!(later.full_at, Some(1_600 + 50 * 600 / 10));

    let unplugged = Battery::reported(Some(&later), 52, false, 1_700);
    assert_eq!(unplugged.since, None);
    assert_eq!(unplugged.full_at, None);

    let full = Battery::reported(Some(&later), 100, true, 3_000);
    assert_eq!(full.full_at, None);
}

#[test]
fn a_battery_level_above_a_hundred_is_refused() {
    assert!(devices::valid_level(100).is_ok());
    assert!(devices::valid_level(101).is_err());
}

#[test]
fn reports_are_kept_between_restarts() {
    let data = tempfile::tempdir().unwrap();
    let dirs = vjproj::paths::Dirs {
        runtime: data.path().to_path_buf(),
        data: data.path().to_path_buf(),
    };
    devices::report(&dirs, "pixel-8a", 40, true, 1_000).unwrap();
    devices::report(&dirs, "pixel-8a", 50, true, 1_600).unwrap();
    let kept = devices::load_batteries(&dirs);
    assert_eq!(kept["pixel-8a"].level, 50);
    assert_eq!(kept["pixel-8a"].full_at, Some(4_600));
}

#[test]
fn the_selected_headset_is_read_from_vjvr() {
    let headset = devices::parse_headset(VJVR).unwrap();
    assert_eq!(headset.id, "headset-TESTSERIAL");
    assert_eq!(headset.name, "Quest 3");
    assert_eq!(headset.kind, Kind::Headset);
    assert!(headset.online);
    assert_eq!(headset.seen, Some(1_790_000_000));
    assert_eq!(
        headset.battery.as_ref().map(|b| (b.level, b.charging)),
        Some((64, true))
    );
    assert_eq!(headset.android.as_deref(), Some("14"));
    assert_eq!(headset.wivrn.as_deref(), Some("26.9"));

    assert_eq!(devices::parse_headset(r#"{"headsets": []}"#), None);
    assert_eq!(devices::parse_headset("vjvr is not running"), None);
}

#[test]
fn the_system_file_needs_a_release() {
    let parsed = devices::parse_system(r#"{"release":"26.11","revision":"abc","built":5}"#);
    assert_eq!(
        parsed,
        Some(System {
            release: "26.11".into(),
            revision: Some("abc".into()),
            built: Some(5),
        })
    );
    assert_eq!(devices::parse_system(r#"{"release":""}"#), None);
    assert_eq!(devices::parse_system("{"), None);
}

#[test]
fn phones_and_computers_are_told_apart_by_their_os() {
    assert_eq!(devices::kind_of("android"), Kind::Phone);
    assert_eq!(devices::kind_of("iOS"), Kind::Phone);
    assert_eq!(devices::kind_of("linux"), Kind::Computer);
    assert_eq!(devices::kind_of(""), Kind::Computer);
}

#[test]
fn this_machine_comes_first_and_an_unseen_machine_is_still_listed() {
    let sightings = [
        sighting("pixel-8a", "android", true, false),
        sighting("main", "linux", true, true),
    ];
    let listed = devices::assemble(&Known {
        sightings: &sightings,
        machines: &machines(&["main", "mini"]),
        system: Some(system("aaa")),
        headset: None,
        batteries: &HashMap::new(),
        told: &[],
        remembered: &[],
    });
    let ids: Vec<&str> = listed.iter().map(|device| device.id.as_str()).collect();
    assert_eq!(ids, ["main", "mini", "pixel-8a"]);
    assert_eq!(found(&listed, "main").system, Some(system("aaa")));

    let mini = found(&listed, "mini");
    assert!(!mini.online);
    assert_eq!(mini.seen, None);
    assert_eq!(mini.system, None);
}

#[test]
fn an_online_device_hides_its_stale_last_seen() {
    let sightings = [sighting("pixel-8a", "android", true, false)];
    let listed = devices::assemble(&Known {
        sightings: &sightings,
        machines: &[],
        system: None,
        headset: None,
        batteries: &HashMap::new(),
        told: &[],
        remembered: &[],
    });
    assert_eq!(found(&listed, "pixel-8a").seen, None);
}

#[test]
fn a_peer_tells_its_own_revision_and_an_offline_one_is_remembered() {
    let sightings = [
        sighting("main", "linux", true, true),
        sighting("mini", "linux", true, false),
        sighting("laptop", "linux", false, false),
    ];
    let told = [
        Device {
            id: "mini".into(),
            here: true,
            system: Some(system("bbb")),
            ..Device::default()
        },
        Device {
            id: "laptop".into(),
            here: false,
            system: Some(system("not-from-itself")),
            ..Device::default()
        },
    ];
    let remembered = [Device {
        id: "laptop".into(),
        system: Some(system("ccc")),
        ..Device::default()
    }];
    let listed = devices::assemble(&Known {
        sightings: &sightings,
        machines: &[],
        system: Some(system("aaa")),
        headset: None,
        batteries: &HashMap::new(),
        told: &told,
        remembered: &remembered,
    });
    assert_eq!(found(&listed, "mini").system, Some(system("bbb")));
    assert_eq!(
        found(&listed, "laptop").system,
        Some(system("ccc")),
        "only a machine's own word about itself counts"
    );
}

#[test]
fn the_newest_phone_battery_wins_wherever_it_was_reported() {
    let sightings = [sighting("pixel-8a", "android", true, false)];
    let mut batteries = HashMap::new();
    batteries.insert(
        "pixel-8a".to_owned(),
        Battery::reported(None, 30, false, 100),
    );
    let told = [Device {
        id: "pixel-8a".into(),
        kind: Kind::Phone,
        battery: Some(Battery::reported(None, 80, false, 200)),
        ..Device::default()
    }];
    let listed = devices::assemble(&Known {
        sightings: &sightings,
        machines: &[],
        system: None,
        headset: None,
        batteries: &batteries,
        told: &told,
        remembered: &[],
    });
    assert_eq!(
        found(&listed, "pixel-8a").battery.as_ref().map(|b| b.level),
        Some(80)
    );
}

#[test]
fn a_connected_headset_beats_what_anyone_remembers_about_it() {
    let live = devices::parse_headset(VJVR).unwrap();
    let remembered = [Device {
        online: true,
        seen: Some(5),
        battery: Some(Battery::reported(None, 1, false, 5)),
        ..live.clone()
    }];
    let listed = devices::assemble(&Known {
        sightings: &[],
        machines: &[],
        system: None,
        headset: Some(live.clone()),
        batteries: &HashMap::new(),
        told: &[],
        remembered: &remembered,
    });
    assert_eq!(listed, [live]);

    let forgotten = devices::assemble(&Known {
        sightings: &[],
        machines: &[],
        system: None,
        headset: None,
        batteries: &HashMap::new(),
        told: &[],
        remembered: &remembered,
    });
    assert_eq!(forgotten.len(), 1);
    assert!(
        !forgotten[0].online,
        "a remembered headset is never shown as connected"
    );
}

#[test]
fn only_devices_worth_remembering_are_kept() {
    let kept = devices::memorable(&[
        Device {
            id: "main".into(),
            system: Some(system("aaa")),
            ..Device::default()
        },
        Device {
            id: "stranger".into(),
            ..Device::default()
        },
        Device {
            id: "headset-1".into(),
            kind: Kind::Headset,
            ..Device::default()
        },
    ]);
    let ids: Vec<&str> = kept.iter().map(|device| device.id.as_str()).collect();
    assert_eq!(ids, ["main", "headset-1"]);
}

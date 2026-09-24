use base64::Engine;
use p256::ecdsa::{Signature, VerifyingKey, signature::Verifier};
use serde_json::{Value, json};
use std::collections::HashSet;
use vjproj::paths::Dirs;
use vjproj::push;
use vjproj::watch::newly_attending;

const AUDIENCE: &str = "https://fcm.googleapis.com";

const SUBJECT: &str = "https://main.example.ts.net";

const NOW: u64 = 1_700_000_000;

fn scratch() -> Dirs {
    let runtime = tempfile::tempdir().unwrap().keep();
    let data = runtime.join("data");
    std::fs::create_dir_all(&data).unwrap();
    Dirs { runtime, data }
}

fn unpack(segment: &str) -> Vec<u8> {
    base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(segment)
        .expect("every segment is base64url without padding")
}

fn read(segment: &str) -> Value {
    serde_json::from_slice(&unpack(segment)).expect("the segment holds json")
}

fn attending(pids: &[u32]) -> HashSet<u32> {
    pids.iter().copied().collect()
}

#[test]
fn a_vapid_token_is_three_base64url_segments() {
    let key = push::Key::kept(&scratch()).unwrap();
    let jwt = key.signed(AUDIENCE, SUBJECT, NOW);
    let segments: Vec<&str> = jwt.split('.').collect();

    assert_eq!(segments.len(), 3, "a jwt is header, claims and signature");
    for segment in &segments {
        assert!(!segment.is_empty());
        assert!(
            segment
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_'),
            "{segment} must be base64url without padding"
        );
    }
}

#[test]
fn a_vapid_token_says_who_it_is_for_and_when_it_expires() {
    let key = push::Key::kept(&scratch()).unwrap();
    let jwt = key.signed(AUDIENCE, SUBJECT, NOW);
    let segments: Vec<&str> = jwt.split('.').collect();

    assert_eq!(read(segments[0]), json!({"typ": "JWT", "alg": "ES256"}));
    assert_eq!(
        read(segments[1]),
        json!({"aud": AUDIENCE, "exp": NOW + 43200, "sub": SUBJECT}),
        "twelve hours is the longest life a push service will accept"
    );
}

#[test]
fn the_subject_of_a_vapid_token_is_a_url_and_never_an_address_to_write_to() {
    let key = push::Key::kept(&scratch()).unwrap();
    let jwt = key.signed(AUDIENCE, SUBJECT, NOW);
    let claims = read(jwt.split('.').nth(1).unwrap());
    let subject = claims["sub"].as_str().unwrap().to_owned();

    assert!(subject.starts_with("https://"));
    assert!(!subject.contains('@'), "an email would name a person");
}

#[test]
fn a_vapid_signature_is_sixty_four_raw_bytes_the_public_key_accepts() {
    let key = push::Key::kept(&scratch()).unwrap();
    let jwt = key.signed(AUDIENCE, SUBJECT, NOW);
    let (signed, mark) = jwt.rsplit_once('.').unwrap();
    let raw = unpack(mark);

    assert_eq!(raw.len(), 64, "es256 is a bare r and s, not a der blob");

    let public = VerifyingKey::from_sec1_bytes(&unpack(&key.public_key())).unwrap();
    let signature = Signature::from_slice(&raw).unwrap();

    assert!(
        public.verify(signed.as_bytes(), &signature).is_ok(),
        "the push service checks this signature against the key we advertise"
    );
    assert!(
        public
            .verify(b"someone else's header.claims", &signature)
            .is_err(),
        "a signature must not carry over to another message"
    );
}

#[test]
fn the_advertised_key_is_an_uncompressed_point_the_browser_can_use() {
    let raw = unpack(&push::Key::kept(&scratch()).unwrap().public_key());

    assert_eq!(raw.len(), 65, "an uncompressed p-256 point is 1 + 32 + 32");
    assert_eq!(raw[0], 0x04, "0x04 is what marks the point uncompressed");
}

#[test]
fn a_signing_key_is_minted_once_and_then_reused() {
    let dirs = scratch();
    let first = push::Key::kept(&dirs).unwrap().public_key();
    let second = push::Key::kept(&dirs).unwrap().public_key();

    assert_eq!(
        first, second,
        "a new key would silently orphan every subscription"
    );
    assert_ne!(first, push::Key::kept(&scratch()).unwrap().public_key());
}

#[test]
fn a_signing_key_and_its_subscriptions_outlive_a_reboot() {
    let runtime = tempfile::tempdir().unwrap();
    let data = tempfile::tempdir().unwrap();
    let dirs = Dirs {
        runtime: runtime.path().to_path_buf(),
        data: data.path().to_path_buf(),
    };

    let minted = push::Key::kept(&dirs).unwrap().public_key();
    push::subscribe(&dirs, "https://push.example/one").unwrap();

    for path in [dirs.push_key(), dirs.subscriptions()] {
        assert!(
            path.starts_with(data.path()),
            "a browser subscription is bound to the key that made it, so {} \
             must live where a reboot cannot wipe it",
            path.display()
        );
    }
    assert_eq!(
        push::Key::kept(&dirs).unwrap().public_key(),
        minted,
        "a fresh key would leave every phone undeliverable with nothing to show for it"
    );
    assert_eq!(push::load(&dirs), vec!["https://push.example/one"]);
}

#[test]
fn nobody_else_on_the_machine_can_read_the_signing_key() {
    let dirs = scratch();
    push::Key::kept(&dirs).unwrap();
    let permissions = std::fs::metadata(dirs.push_key()).unwrap().permissions();

    assert_eq!(
        std::os::unix::fs::PermissionsExt::mode(&permissions) & 0o777,
        0o600,
        "the key speaks for this machine, so it stays with this account"
    );
}

#[test]
fn a_push_endpoint_is_addressed_by_its_origin_alone() {
    assert_eq!(
        push::audience_of("https://fcm.googleapis.com/fcm/send/abc"),
        Some("https://fcm.googleapis.com".to_owned())
    );
    assert_eq!(
        push::audience_of("https://updates.push.services.mozilla.com/wpush/v2/gAAA-bbb"),
        Some("https://updates.push.services.mozilla.com".to_owned())
    );
    assert_eq!(
        push::audience_of("https://fcm.googleapis.com"),
        Some("https://fcm.googleapis.com".to_owned()),
        "a bare origin is already the audience"
    );
    assert_eq!(
        push::audience_of("https://push.example:8443/send?x=1"),
        Some("https://push.example:8443".to_owned())
    );
}

#[test]
fn nonsense_never_passes_for_a_push_endpoint() {
    for garbage in [
        "",
        "not a url at all",
        "fcm.googleapis.com/fcm/send/abc",
        "://nowhere/path",
        "https:///path",
        "ht tp://push.example",
    ] {
        assert_eq!(
            push::audience_of(garbage),
            None,
            "{garbage:?} must not be signed for"
        );
        assert!(!push::secure(garbage));
    }
    assert!(
        !push::secure("http://push.example/send"),
        "a plain http endpoint is not a push service we will talk to"
    );
}

#[test]
fn a_subscription_survives_being_written_and_read_back() {
    let dirs = scratch();
    assert!(push::load(&dirs).is_empty(), "nobody has subscribed yet");

    push::subscribe(&dirs, "https://push.example/one").unwrap();
    push::subscribe(&dirs, "https://push.example/two").unwrap();
    assert_eq!(
        push::load(&dirs),
        vec![
            "https://push.example/one".to_owned(),
            "https://push.example/two".to_owned()
        ]
    );

    push::forget(&dirs, "https://push.example/one").unwrap();
    assert_eq!(push::load(&dirs), vec!["https://push.example/two"]);

    push::forget(&dirs, "https://push.example/never-there").unwrap();
    assert_eq!(push::load(&dirs), vec!["https://push.example/two"]);
}

#[test]
fn subscribing_twice_from_one_phone_stores_one_endpoint() {
    let dirs = scratch();
    for _ in 0..5 {
        push::subscribe(&dirs, "https://push.example/one").unwrap();
    }
    assert_eq!(push::load(&dirs), vec!["https://push.example/one"]);
}

#[test]
fn the_subscription_list_stops_at_twenty_and_drops_the_oldest() {
    let dirs = scratch();
    for n in 0..25 {
        push::subscribe(&dirs, &format!("https://push.example/{n}")).unwrap();
    }
    let kept = push::load(&dirs);

    assert_eq!(kept.len(), 20, "an unbounded list is a slow leak");
    assert_eq!(kept.first().unwrap(), "https://push.example/5");
    assert_eq!(kept.last().unwrap(), "https://push.example/24");
}

#[test]
fn an_agent_that_starts_asking_is_pushed_for_once() {
    let before = attending(&[]);
    let now = attending(&[42]);

    assert_eq!(newly_attending(&before, &now), vec![42]);
}

#[test]
fn an_agent_that_keeps_asking_is_not_pushed_for_again() {
    let asking = attending(&[42, 7]);

    assert!(
        newly_attending(&asking, &asking).is_empty(),
        "a phone buzzing every tick is worse than no phone"
    );
}

#[test]
fn an_agent_that_stops_asking_is_pushed_for_never() {
    let before = attending(&[42, 7]);
    let now = attending(&[7]);

    assert!(newly_attending(&before, &now).is_empty());
}

#[test]
fn an_agent_that_asks_again_after_a_pause_is_pushed_for_again() {
    let asking = attending(&[42]);
    let quiet = attending(&[]);

    assert_eq!(newly_attending(&quiet, &asking), vec![42]);
    assert!(newly_attending(&asking, &quiet).is_empty());
    assert_eq!(newly_attending(&quiet, &asking), vec![42]);
}

#[test]
fn several_agents_asking_at_once_are_each_pushed_for() {
    let before = attending(&[7]);
    let now = attending(&[7, 42, 13]);

    assert_eq!(newly_attending(&before, &now), vec![13, 42]);
}

#[test]
fn a_push_service_that_has_forgotten_a_phone_says_so() {
    assert!(push::gone(Some(404)));
    assert!(push::gone(Some(410)));
    assert!(!push::gone(Some(201)));
    assert!(!push::gone(Some(429)));
    assert!(!push::gone(Some(500)), "a bad day is not a dead phone");
    assert!(!push::gone(None), "curl failing to run proves nothing");
}

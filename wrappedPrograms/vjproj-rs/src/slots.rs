use anyhow::{Result, bail};

pub const NUM_PROJECTS: u8 = 5;

pub const VISIBLE_TAGS: u8 = 9;

pub const VISIBLE_SLOTS: [u8; 1] = [1];

pub const HOME_SLOT: u8 = VISIBLE_SLOTS[0];

pub const STICKY_TAGS: [u8; 8] = [2, 3, 4, 5, 6, 7, 8, 9];

pub const TOTAL_TAGS: u8 = block_start(VISIBLE_TAGS + 1) - 1;

const _: () = assert!(TOTAL_TAGS <= 31);

const fn is_slot_const(visible: u8) -> bool {
    let mut i = 0;
    while i < VISIBLE_SLOTS.len() {
        if VISIBLE_SLOTS[i] == visible {
            return true;
        }
        i += 1;
    }
    false
}

const fn is_sticky_const(visible: u8) -> bool {
    let mut i = 0;
    while i < STICKY_TAGS.len() {
        if STICKY_TAGS[i] == visible {
            return true;
        }
        i += 1;
    }
    false
}

const _: () = {
    let mut v = 1;
    while v <= VISIBLE_TAGS {
        assert!(
            is_slot_const(v) != is_sticky_const(v),
            "every workspace must be exactly one of slot or sticky"
        );
        v += 1;
    }
};

const fn run_width(visible: u8) -> u8 {
    if is_slot_const(visible) {
        NUM_PROJECTS
    } else {
        1
    }
}

const fn block_start(visible: u8) -> u8 {
    let mut start = 1;
    let mut v = 1;
    while v < visible {
        start += run_width(v);
        v += 1;
    }
    start
}

pub fn is_slot(visible: u8) -> bool {
    VISIBLE_SLOTS.contains(&visible)
}

pub fn is_sticky(visible: u8) -> bool {
    STICKY_TAGS.contains(&visible)
}

pub fn real_tag(project: u8, visible: u8) -> Result<u8> {
    require_project(project)?;
    if visible < 1 || visible > VISIBLE_TAGS {
        bail!("workspace must be between 1 and {VISIBLE_TAGS}, got {visible}");
    }
    let start = block_start(visible);
    Ok(if is_slot(visible) {
        start + project - 1
    } else {
        start
    })
}

pub fn visible_for(project: u8, real: u8) -> Option<u8> {
    (1..=VISIBLE_TAGS).find(|&v| real_tag(project, v).is_ok_and(|r| r == real))
}

pub fn valid_project(n: u8) -> bool {
    (1..=NUM_PROJECTS).contains(&n)
}

pub fn require_project(n: u8) -> Result<()> {
    if !valid_project(n) {
        bail!("project must be between 1 and {NUM_PROJECTS}, got {n}");
    }
    Ok(())
}

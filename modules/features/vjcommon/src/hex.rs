use std::fmt::Write as _;

pub fn encode(bytes: &[u8]) -> String {
    bytes.iter().fold(String::new(), |mut out, byte| {
        let _ = write!(out, "{byte:02x}");
        out
    })
}

#[cfg(test)]
mod tests {
    use super::encode;

    #[test]
    fn encodes_nothing_as_the_empty_string() {
        assert_eq!(encode(&[]), "");
    }

    #[test]
    fn pads_every_byte_to_two_lowercase_digits() {
        assert_eq!(encode(&[0x00, 0x0f, 0xa0, 0xff]), "000fa0ff");
    }

    #[test]
    fn matches_the_lower_hex_formatting_it_replaces() {
        let bytes: Vec<u8> = (0u8..=255).collect();
        let expected: String = bytes.iter().map(|byte| format!("{byte:02x}")).collect();
        assert_eq!(encode(&bytes), expected);
    }
}

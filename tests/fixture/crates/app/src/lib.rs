//! A crate of the fixture workspace that depends on `fixture-base`.

/// Doubles a number.
///
/// ```
/// assert_eq!(fixture_app::double(21), 42);
/// ```
pub fn double(x: u32) -> u32 {
    fixture_base::add(x, x)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn doubles() {
        assert_eq!(double(21), 42);
    }
}

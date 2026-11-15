//! The base crate of the fixture workspace.

/// Adds two numbers.
///
/// ```
/// assert_eq!(fixture_base::add(2, 3), 5);
/// ```
pub fn add(a: u32, b: u32) -> u32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn adds() {
        assert_eq!(add(2, 3), 5);
    }
}

pub fn changed(x: i32) -> i32 {
    x + 1
}

pub fn untouched(a: i32, b: i32) -> i32 {
    a + b
}

#[test]
fn checks_functions() {
    assert_eq!(changed(2), 3);
    // Deliberately misses the mutation of + to * in untouched.
    assert_eq!(untouched(2, 2), 4);
}

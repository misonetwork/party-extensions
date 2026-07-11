// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module platform_link::platform_link_tests;

// Aliased so the bare `platform_link` name stays free for `location = …` below.
use platform_link::platform_link as pl;
use std::unit_test::assert_eq;

/// A stand-in payload for exercising the generic storage.
public struct FooData has copy, drop, store { v: u64 }

#[test]
fun wraps_and_reads_payload() {
    let link = pl::new(FooData { v: 42 });
    assert_eq!(link.data().v, 42);
}

#[test]
fun set_get_borrow_remove() {
    let ctx = &mut tx_context::dummy();
    let mut uid = object::new(ctx);

    assert!(!pl::exists_<FooData>(&uid));
    assert!(pl::get<FooData>(&uid).is_none());

    pl::set(&mut uid, pl::new(FooData { v: 1 }));
    assert!(pl::exists_<FooData>(&uid));
    assert_eq!(pl::borrow<FooData>(&uid).data().v, 1);

    // Setting again replaces the existing link rather than aborting.
    pl::set(&mut uid, pl::new(FooData { v: 2 }));
    assert_eq!(pl::get<FooData>(&uid).destroy_some().data().v, 2);

    let removed = pl::remove<FooData>(&mut uid);
    assert_eq!(removed.data().v, 2);
    assert!(!pl::exists_<FooData>(&uid));

    uid.delete();
}

#[test]
fun clear_is_a_noop_when_absent() {
    let ctx = &mut tx_context::dummy();
    let mut uid = object::new(ctx);

    pl::clear<FooData>(&mut uid); // absent — no-op
    pl::set(&mut uid, pl::new(FooData { v: 7 }));
    pl::clear<FooData>(&mut uid); // present — removed
    assert!(!pl::exists_<FooData>(&uid));

    uid.delete();
}

#[test, expected_failure(abort_code = 0, location = platform_link::platform_link)] // ENoLink
fun borrow_missing_aborts() {
    let ctx = &mut tx_context::dummy();
    let uid = object::new(ctx);
    let _ = pl::borrow<FooData>(&uid);
    abort
}

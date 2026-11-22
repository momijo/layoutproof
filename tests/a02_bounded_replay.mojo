# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

from std.collections import List
from std.testing import assert_true
from layoutproof.a02 import (
    Checks, Layout, Op, Order, Program, Reason, Status, Verdict, replay_counterexample, verify,
)


def main() raises:
    var source = Layout([4], [-1], 3, 4, 123, True)
    var reference = Program([Op.slice(0, 0, 2, 2)], False)
    var mutant = Program([Op.slice(0, 0, 2, 1)], False)
    # The two maps read backing offsets [3, 1] and [3, 2].
    var hand_checked = Verdict(Status.FAIL, Reason.LOGICAL, 1, -1, "")
    assert_true(replay_counterexample(source, reference, mutant, [], Checks.FULL, hand_checked))
    var observed = verify(source, reference, mutant, [])
    assert_true(observed.status == Status.FAIL and observed.ordinal == hand_checked.ordinal)
    hand_checked.ordinal = 0
    assert_true(not replay_counterexample(source, reference, mutant, [], Checks.FULL, hand_checked))

    var invalid = Program([Op.broadcast([1])], False)
    var rejected = verify(source, reference, invalid, [])
    assert_true(rejected.status == Status.FAIL and rejected.reason == Reason.INVALID_CANDIDATE)
    assert_true(replay_counterexample(source, reference, invalid, [], Checks.FULL, rejected))
    assert_true(not replay_counterexample(source, invalid, invalid, [], Checks.FULL, rejected))
    var exceeds_before_invalid = Program([Op.broadcast([2, 4]), Op.broadcast([1])], False)
    assert_true(verify(source, reference, exceeds_before_invalid, [], cap=4).status == Status.UNKNOWN)
    assert_true(not replay_counterexample(source, reference, exceeds_before_invalid, [], Checks.FULL, rejected, cap=4))

    var empty = Layout([0], [0], 0, 0, 4, True)
    var identity = Program([], False)
    var empty_copy = Program([Op.reshape([0], Order.C, True)], False)
    var mismatch = verify(empty, identity, empty_copy, [], cap=0)
    assert_true(mismatch.status == Status.FAIL and mismatch.reason == Reason.ADDRESS)
    assert_true(replay_counterexample(empty, identity, empty_copy, [], Checks.FULL, mismatch, cap=0))

    var write_copy = Program([Op.reshape([4], Order.C, True)], True)
    var write_view = Program([], True)
    var peers = List[Layout]()
    peers.append(Layout([1], [0], 1, 4, 123, False))
    var alias_only = Checks(False, True)
    var conflict = verify(source, write_copy, write_view, peers, alias_only)
    assert_true(conflict.status == Status.FAIL and conflict.reason == Reason.ALIAS and conflict.ordinal == 2)
    assert_true(replay_counterexample(source, write_copy, write_view, peers, alias_only, conflict))
    assert_true(not replay_counterexample(source, write_copy, write_view, [], alias_only, conflict))
    print("PASS: bounded replay from backward maps, preconditions and live peers")

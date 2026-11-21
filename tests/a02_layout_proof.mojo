# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

from std.collections import List
from std.testing import assert_equal, assert_true
from layoutproof.a02 import Checks, Layout, Op, Order, Program, Reason, Status
from layoutproof.a02.arithmetic import add, mul
from layoutproof.a02.oracle import interpret
from layoutproof.a02.verifier import replay_counterexample, verify


def ranks() raises:
    for rank in range(17):
        var shape = List[Int](length=rank, fill=1)
        var strides = List[Int](length=rank, fill=0)
        if rank > 0:
            shape[rank - 1] = 3
            strides[rank - 1] = -1
        var source = Layout(shape^, strides^, 2, 3, 12, True)
        var reference = Program([Op.expand(rank), Op.squeeze(rank)], True)
        var identity = Program([], True)
        assert_true(verify(source, reference, identity, []).status == Status.PASS)
        if rank > 0:
            var reverse = Program([Op.flip(rank - 1)], True)
            var bad = verify(source, reference, reverse, [])
            assert_true(bad.status == Status.FAIL and bad.reason == Reason.LOGICAL)
            assert_equal(bad.ordinal, 0)
            assert_true(replay_counterexample(source, reference, reverse, [], Checks.FULL, bad))
            bad.ordinal = 1
            assert_true(not replay_counterexample(source, reference, reverse, [], Checks.FULL, bad))


def compositions() raises:
    var source = Layout([2, 3], [3, 1], 0, 6, 1, True)
    var round_trip = Program([
        Op.transpose(0, 1), Op.reshape([6], Order.F), Op.reshape([3, 2], Order.F),
        Op.permute([1, 0]), Op.expand(0), Op.squeeze(0),
    ], False)
    var identity = Program([], False)
    assert_true(verify(source, round_trip, identity, []).status == Status.PASS)
    var wrong_order = Program([Op.transpose(0, 1), Op.reshape([6], Order.C)], False)
    var invalid = verify(source, round_trip, wrong_order, [])
    assert_true(invalid.status == Status.FAIL and invalid.reason == Reason.INVALID_CANDIDATE)
    var dense = Program([Op.reshape([3, 2], Order.C), Op.reshape([6], Order.C)], False)
    var direct = Program([Op.reshape([6], Order.C)], False)
    assert_true(verify(source, dense, direct, []).status == Status.PASS)
    var f_dense = Layout([2, 3], [1, 2], 0, 6, 1, True)
    var flatten_f = Program([Op.reshape([6], Order.F)], False)
    var frame = interpret(f_dense, flatten_f)
    assert_equal(frame.cells[1].source, 3)
    assert_equal(frame.cells[1].physical, 1)

    var stepped = Program([Op.flip(1), Op.slice(1, 0, 2, 2)], False)
    var fused = Program([Op.slice(1, 2, 2, -2)], False)
    assert_true(verify(source, stepped, fused, []).status == Status.PASS)
    assert_true(verify(source, stepped, fused, [], finite_only=True).status == Status.PASS)
    var off_by_one = Program([Op.slice(1, 1, 2, -1)], False)
    var mismatch = verify(source, stepped, off_by_one, [])
    assert_true(mismatch.status == Status.FAIL and mismatch.reason == Reason.LOGICAL)
    assert_true(replay_counterexample(source, stepped, off_by_one, [], Checks.FULL, mismatch))
    var bad_domain = Program([Op.slice(1, 2, 1, -2)], False)
    var domain = verify(source, stepped, bad_domain, [])
    assert_true(domain.reason == Reason.DOMAIN)
    assert_true(replay_counterexample(source, stepped, bad_domain, [], Checks.FULL, domain))
    var broadcast_then = Program([Op.expand(0), Op.broadcast([4, 2, 3])], False)
    var implicit = Program([Op.broadcast([4, 2, 3])], False)
    assert_true(verify(source, broadcast_then, implicit, []).status == Status.PASS)
    assert_true(verify(source, broadcast_then, implicit, [], cap=12).status == Status.UNKNOWN)


def permission_and_address() raises:
    var source = Layout([1], [0], 0, 1, 0, True)
    var view = Program([Op.reshape([1, 1], Order.C)], False)
    var copy = Program([Op.reshape([1, 1], Order.C, True)], False)
    var bad = verify(source, view, copy, [])
    assert_true(bad.status == Status.FAIL and bad.reason == Reason.ADDRESS)
    assert_true(replay_counterexample(source, view, copy, [], Checks.FULL, bad))
    assert_true(verify(source, view, copy, [], Checks(False, True)).status == Status.PASS)

    var write = Program([Op.broadcast([4])], True)
    var read = Program([Op.broadcast([4])], False)
    var denied = verify(source, write, write, [])
    assert_true(denied.status == Status.REJECTED and denied.reason == Reason.ALIAS)
    assert_true(verify(source, write, Program([], True), []).status == Status.REJECTED)
    assert_equal(denied.ordinal, 0)
    assert_equal(denied.other, 1)
    assert_true(verify(source, write, write, [], Checks(True, False)).status == Status.PASS)
    assert_true(verify(source, read, read, []).status == Status.PASS)
    var write_copy = Program([Op.broadcast([4]), Op.reshape([4], Order.C, True)], True)
    var alias_only = Checks(False, True)
    var unsafe = verify(source, write_copy, write, [], alias_only)
    assert_true(unsafe.status == Status.FAIL and unsafe.reason == Reason.ALIAS)
    assert_true(replay_counterexample(source, write_copy, write, [], alias_only, unsafe))
    assert_true(verify(source, read, write, []).reason == Reason.PERMISSION)

    var identity = Program([], True)
    var owned = Layout([2], [2], 0, 4, 6, True)
    var disjoint = Layout([2], [2], 1, 4, 6, False)
    var overlapping = Layout([1], [0], 2, 4, 6, False)
    assert_true(verify(owned, identity, identity, [disjoint^]).status == Status.PASS)
    var denied_peer = verify(owned, identity, identity, [overlapping^])
    assert_true(denied_peer.status == Status.REJECTED and denied_peer.reason == Reason.ALIAS)
    assert_equal(denied_peer.ordinal, 1)
    assert_equal(denied_peer.other, -1)
    var read_only = Layout([2], [2], 0, 4, 6, False)
    assert_true(verify(read_only, identity, identity, []).reason == Reason.PERMISSION)
    var equal_values = Layout([2], [0], 0, 1, 0, False)
    var order = interpret(equal_values, Program([], False))
    var flipped = interpret(equal_values, Program([Op.flip(0)], False))
    assert_equal(order.cells[0].value, flipped.cells[0].value)
    assert_true(order.cells[0].source != flipped.cells[0].source)


def boundaries() raises:
    var empty = Layout([Int.MAX, 0, Int.MAX], [Int.MIN, 0, Int.MAX], 1, 1, 3, True)
    var moved = Program([Op.flip(0), Op.transpose(0, 2), Op.reshape([0], Order.F)], True)
    var direct = Program([Op.reshape([0], Order.C)], True)
    assert_true(verify(empty, moved, direct, [], cap=0).status == Status.PASS)
    var reshape_copy = Program([Op.reshape([0], Order.C, True)], True)
    assert_true(verify(empty, moved, reshape_copy, [], cap=0).reason == Reason.ADDRESS)
    var identity = Program([], False)
    var malformed = List[Layout]()
    malformed.append(Layout([0, -1], [0, 0], 0, 0, 0, True))
    malformed.append(Layout([2], [], 0, 1, 0, True))
    malformed.append(Layout([0], [0], 2, 1, 0, True))
    malformed.append(Layout([], [], 1, 1, 0, True))
    malformed.append(Layout([2], [-1], 0, 2, 0, True))
    malformed.append(Layout([3], [Int.MAX], 0, 2, 0, True))
    malformed.append(Layout([Int.MAX, 2], [0, 0], 0, 1, 0, True))
    malformed.append(Layout([0], [0], 0, Int.MAX, 0, True))
    malformed.append(Layout([0], [0], 0, 0, -1, True))
    for item in malformed:
        assert_true(verify(item, identity, identity, []).reason == Reason.INVALID_INPUT)

    var tiny = Layout([1], [Int.MIN], 0, 1, 0, True)
    var singleton = Program([Op.slice(0, 0, 1, Int.MIN)], False)
    assert_true(verify(tiny, identity, singleton, []).status == Status.PASS)
    var bad = List[Op]()
    bad.append(Op.slice(0, 0, 2, Int.MIN))
    bad.append(Op.slice(0, 0, 0, 0))
    bad.append(Op.squeeze(1))
    bad.append(Op.expand(2))
    bad.append(Op.permute([0, 0]))
    bad.append(Op.transpose(0, 1))
    bad.append(Op.flip(-1))
    bad.append(Op.broadcast([-1]))
    bad.append(Op.reshape([2], Order.F))
    for op in bad:
        var program = Program([op.copy()], False)
        assert_true(verify(tiny, identity, program, []).reason == Reason.INVALID_CANDIDATE)
        assert_true(verify(tiny, program, identity, []).reason == Reason.INVALID_REFERENCE)
    assert_equal(mul(Int.MIN, 1), Int.MIN)
    assert_equal(mul(Int.MIN, 0), 0)
    assert_equal(add(Int.MIN, Int.MAX), -1)
    var trapped = False
    try:
        _ = mul(Int.MIN, -1)
    except:
        trapped = True
    assert_true(trapped)
    trapped = False
    try:
        _ = add(Int.MAX, 1)
    except:
        trapped = True
    assert_true(trapped)


def main() raises:
    ranks()
    compositions()
    permission_and_address()
    boundaries()
    print("PASS: rank 0–16, compositions, ablations, replay, alias and arithmetic controls")

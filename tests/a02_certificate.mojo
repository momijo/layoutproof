# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

from layoutproof.a02 import Layout, Op, Program, Reason, Status, verify
from layoutproof.a02.replay import AxisImage, Certificate, replay
from layoutproof.a02.solver import certify, manual_double_flip
from std.testing import assert_true


def main() raises:
    var identity = Program([], True)
    for rank in range(1, 17):
        var reference = Program([Op.flip(rank - 1), Op.flip(rank - 1)], True)
        var result = certify(reference, identity, rank)
        assert_true(result.status == Status.PASS)
        assert_true(manual_double_flip(reference, identity, rank))
        var certificate = result.certificate.take()
        assert_true(replay(reference, identity, certificate))
        certificate.image[rank - 1] = AxisImage(rank - 1, True)
        assert_true(not replay(reference, identity, certificate))

    var reordered = Program([Op.transpose(0, 2), Op.flip(2), Op.permute([2, 1, 0])], True)
    var same = Program([Op.flip(0)], True)
    var positive = certify(reordered, same, 3)
    assert_true(positive.status == Status.PASS)
    for a in range(4):
        for b in range(3):
            for c in range(4):
                var source = Layout([a, b, c], [b * c, c, 1], 0, a * b * c, 0, True)
                assert_true(verify(source, reordered, same, []).status == Status.PASS)
    var different = certify(reordered, Program([Op.flip(1)], True), 3)
    assert_true(different.status == Status.UNKNOWN)
    assert_true(not different.certificate)
    var unsupported = certify(Program([Op.slice(0, 0, 1, 1)], True), identity, 2)
    assert_true(unsupported.status == Status.UNSUPPORTED)
    var too_large = certify(identity, identity, 65)
    assert_true(too_large.status == Status.UNKNOWN and too_large.reason == Reason.WORK_LIMIT)
    assert_true(not replay(Program([Op.permute([0, 0])], True), identity,
                           Certificate(2, [AxisImage(0, False), AxisImage(1, False)])))
    assert_true(certify(identity, Program([], False), 0).status == Status.FAIL)
    print("PASS: symbolic axis certificates, bounds and tamper rejection")

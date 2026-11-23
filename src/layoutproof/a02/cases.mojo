# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: src/layoutproof/a02/cases.mojo
# Module: layoutproof.a02.cases

"""Exploratory regression inputs for the preflight runner."""

from std.collections import List
from .ir import Layout, Op, Order, Program, Reason, Status


@fieldwise_init
struct Case(Movable):
    var source: Layout
    var reference: Program
    var candidate: Program
    var peers: List[Layout]
    var expected: Status
    var reason: Reason


def fixture(name: String, seed: Int) raises -> Case:
    var width = 3 + seed % 7
    var source = Layout([2, width], [width, 1], 0, 2 * width, 0, True)
    if name == "flip-slice" or name == "slice-mutant":
        var reference = Program([Op.flip(1), Op.slice(1, 0, 2, 2)], False)
        var start = width - 1
        if name == "slice-mutant":
            var bad = Program([Op.slice(1, start, 2, -1)], False)
            return Case(source^, reference^, bad^, [], Status.FAIL, Reason.LOGICAL)
        var candidate = Program([Op.slice(1, start, 2, -2)], False)
        return Case(source^, reference^, candidate^, [], Status.PASS, Reason.EQUIVALENT)
    if name == "copy-mutant":
        var view = Program([Op.reshape([2 * width], Order.C)], False)
        var copy = Program([Op.reshape([2 * width], Order.C, True)], False)
        return Case(source^, view^, copy^, [], Status.FAIL, Reason.ADDRESS)
    if name == "aliased-write":
        var scalar = Layout([], [], 0, 1, 0, True)
        var write = Program([Op.broadcast([width])], True)
        return Case(scalar^, write.copy(), write^, [], Status.REJECTED, Reason.ALIAS)
    raise Error("unknown A02 fixture")


def affine_fixture(name: String, seed: Int) -> Case:
    var extent = 1_000_000_000 + 2 * (seed % 7)
    var source = Layout([extent], [-1], extent - 1, extent, 0, True)
    var reference = Program([Op.flip(0), Op.slice(0, 0, extent // 2, 2)], False)
    if name == "affine-slice-mutant":
        var mutated = Program([Op.slice(0, extent - 1, extent // 2, -1)], False)
        return Case(source^, reference^, mutated^, [], Status.FAIL, Reason.LOGICAL)
    var fused = Program([Op.slice(0, extent - 1, extent // 2, -2)], False)
    return Case(source^, reference^, fused^, [], Status.PASS, Reason.EQUIVALENT)

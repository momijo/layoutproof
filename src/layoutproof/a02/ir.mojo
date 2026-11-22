# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

"""CPU FP32 layout IR. All strides, offsets and capacities count elements."""

from std.collections import List


@fieldwise_init
struct Order(ImplicitlyCopyable, Equatable):
    var code: Int
    comptime C = Self(0)
    comptime F = Self(1)


@fieldwise_init
struct Kind(ImplicitlyCopyable, Equatable):
    var code: Int
    comptime PERMUTE = Self(0)
    comptime TRANSPOSE = Self(1)
    comptime SLICE = Self(2)
    comptime FLIP = Self(3)
    comptime EXPAND = Self(4)
    comptime SQUEEZE = Self(5)
    comptime BROADCAST = Self(6)
    comptime RESHAPE = Self(7)


@fieldwise_init
struct Op(Copyable, Movable):
    var kind: Kind
    var axis: Int
    var first: Int
    var length: Int
    var step: Int
    var dims: List[Int]
    var order: Order
    var materialize: Bool

    @staticmethod
    def permute(var axes: List[Int]) -> Self:
        return Self(Kind.PERMUTE, 0, 0, 0, 0, axes^, Order.C, False)

    @staticmethod
    def transpose(a: Int, b: Int) -> Self:
        return Self(Kind.TRANSPOSE, a, b, 0, 0, [], Order.C, False)

    @staticmethod
    def slice(axis: Int, start: Int, count: Int, step: Int) -> Self:
        return Self(Kind.SLICE, axis, start, count, step, [], Order.C, False)

    @staticmethod
    def flip(axis: Int) -> Self:
        return Self(Kind.FLIP, axis, 0, 0, 0, [], Order.C, False)

    @staticmethod
    def expand(axis: Int) -> Self:
        return Self(Kind.EXPAND, axis, 0, 0, 0, [], Order.C, False)

    @staticmethod
    def squeeze(axis: Int) -> Self:
        return Self(Kind.SQUEEZE, axis, 0, 0, 0, [], Order.C, False)

    @staticmethod
    def broadcast(var shape: List[Int]) -> Self:
        return Self(Kind.BROADCAST, 0, 0, 0, 0, shape^, Order.C, False)

    @staticmethod
    def reshape(var shape: List[Int], order: Order, materialize: Bool = False) -> Self:
        return Self(Kind.RESHAPE, 0, 0, 0, 0, shape^, order, materialize)


@fieldwise_init
struct Layout(Copyable, Movable):
    var shape: List[Int]
    var strides: List[Int]
    var offset: Int
    var capacity: Int
    var storage: Int
    var write_capable: Bool


@fieldwise_init
struct Program(Copyable, Movable):
    var ops: List[Op]
    var writable: Bool


@fieldwise_init
struct Checks(ImplicitlyCopyable):
    var address: Bool
    var alias: Bool
    comptime FULL = Self(True, True)


@fieldwise_init
struct Status(ImplicitlyCopyable, Equatable):
    var code: StaticString
    comptime PASS = Self("PASS")
    comptime REJECTED = Self("REJECTED")
    comptime FAIL = Self("FAIL")
    comptime UNKNOWN = Self("UNKNOWN")
    comptime UNSUPPORTED = Self("UNSUPPORTED")
    comptime NOT_RUN = Self("NOT_RUN")
    comptime ERROR = Self("ERROR")


@fieldwise_init
struct Reason(ImplicitlyCopyable, Equatable):
    var code: StaticString
    comptime EQUIVALENT = Self("EQUIVALENT")
    comptime CONDITIONAL_EQUIVALENCE = Self("CONDITIONAL_EQUIVALENCE")
    comptime INVALID_INPUT = Self("INVALID_INPUT")
    comptime INVALID_REFERENCE = Self("INVALID_REFERENCE")
    comptime INVALID_CANDIDATE = Self("INVALID_CANDIDATE")
    comptime WORK_LIMIT = Self("WORK_LIMIT")
    comptime DOMAIN = Self("DOMAIN")
    comptime LOGICAL = Self("LOGICAL")
    comptime VALUE = Self("VALUE")
    comptime ADDRESS = Self("ADDRESS")
    comptime PERMISSION = Self("PERMISSION")
    comptime ALIAS = Self("ALIAS")
    comptime ORACLE_DISAGREEMENT = Self("ORACLE_DISAGREEMENT")
    comptime PROOF_FRAGMENT = Self("PROOF_FRAGMENT")
    comptime CERTIFICATE = Self("CERTIFICATE")


@fieldwise_init
struct Verdict(Movable):
    var status: Status
    var reason: Reason
    # C-order coordinate ordinals, -1 when no coordinate applies.
    var ordinal: Int
    var other: Int
    var detail: String

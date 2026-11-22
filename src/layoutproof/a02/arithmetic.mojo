# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

"""Checked signed arithmetic and coordinate primitives for the lowering."""

from std.collections import List
from .ir import Layout, Order


def add(a: Int, b: Int) raises -> Int:
    if (b > 0 and a > Int.MAX - b) or (b < 0 and a < Int.MIN - b):
        raise Error("signed addition overflow")
    return a + b


def magnitude(x: Int) -> UInt:
    if x < 0:
        return UInt(-(x + 1)) + 1
    return UInt(x)


def mul(a: Int, b: Int) raises -> Int:
    var x = magnitude(a)
    var y = magnitude(b)
    var negative = (a < 0) != (b < 0)
    var limit = UInt(Int.MAX) + UInt(negative)
    if y != 0 and x > limit // y:
        raise Error("signed product overflow")
    var product = x * y
    if negative:
        if product == UInt(Int.MAX) + 1:
            return Int.MIN
        return -Int(product)
    return Int(product)


def count(shape: List[Int]) raises -> Int:
    var empty = False
    for axis in range(len(shape)):
        if shape[axis] < 0:
            raise Error("negative extent")
        empty = empty or shape[axis] == 0
    if empty:
        return 0
    var result = 1
    for axis in range(len(shape)):
        result = mul(result, shape[axis])
    return result


def validate(layout: Layout) raises:
    if len(layout.shape) != len(layout.strides):
        raise Error("stride rank mismatch")
    if layout.capacity < 0 or layout.capacity > Int.MAX // 4:
        raise Error("invalid FP32 allocation capacity")
    if layout.offset < 0 or layout.offset > layout.capacity:
        raise Error("invalid origin")
    if count(layout.shape) == 0:
        return
    var lo = layout.offset
    var hi = layout.offset
    for axis in range(len(layout.shape)):
        var delta = mul(layout.shape[axis] - 1, layout.strides[axis])
        if delta < 0:
            lo = add(lo, delta)
        else:
            hi = add(hi, delta)
    if lo < 0 or hi >= layout.capacity:
        raise Error("reachable address outside allocation")


def address(layout: Layout, indices: List[Int]) raises -> Int:
    if len(indices) != len(layout.shape):
        raise Error("coordinate rank mismatch")
    var result = layout.offset
    for axis in range(len(indices)):
        if indices[axis] < 0 or indices[axis] >= layout.shape[axis]:
            raise Error("coordinate outside domain")
        result = add(result, mul(indices[axis], layout.strides[axis]))
    if result < 0 or result >= layout.capacity:
        raise Error("address outside allocation")
    return result


def ordered_axis(rank: Int, position: Int, order: Order) -> Int:
    if order == Order.C:
        return rank - 1 - position
    return position


def dense(shape: List[Int], order: Order) raises -> List[Int]:
    var strides = List[Int](length=len(shape), fill=0)
    if count(shape) == 0:
        return strides^
    var stride = 1
    for position in range(len(shape)):
        var axis = ordered_axis(len(shape), position, order)
        if shape[axis] > 1:
            strides[axis] = stride
        stride = mul(stride, shape[axis])
    return strides^


def decode(shape: List[Int], ordinal: Int, order: Order) -> List[Int]:
    # Only used with ordinals in a nonempty, preflighted domain.
    var result = List[Int](length=len(shape), fill=0)
    var rest = ordinal
    for position in range(len(shape)):
        var axis = ordered_axis(len(shape), position, order)
        result[axis] = rest % shape[axis]
        rest = rest // shape[axis]
    return result^


def encode(shape: List[Int], indices: List[Int], order: Order) raises -> Int:
    var result = 0
    for position in range(len(shape) - 1, -1, -1):
        var axis = ordered_axis(len(shape), position, order)
        result = add(mul(result, shape[axis]), indices[axis])
    return result


def equal(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for axis in range(len(a)):
        if a[axis] != b[axis]:
            return False
    return True

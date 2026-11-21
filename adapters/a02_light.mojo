# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

"""Read-only dependency adapter for Momijo Light HostStorage views."""

from std.testing import assert_equal, assert_true
from layoutproof.a02 import Layout, Op, Order, Program
from layoutproof.a02.oracle import interpret
from momijo.tensor_light.factory.creation import ones
from momijo.tensor_light.internal.status import TensorStatus
from momijo.tensor_light.shape.shape import TensorShape
from momijo.tensor_light.shape.shape_storage import StaticRankArray


def pair(i: Int, j: Int) -> StaticRankArray[2]:
    var result = StaticRankArray[2]()
    result.set(0, i)
    result.set(1, j)
    return result


def check_light() raises:
    var source = Layout([2, 3], [3, 1], 0, 6, 0, True)
    var program = Program([Op.transpose(0, 1), Op.flip(0)], False)
    var expected = interpret(source, program)
    var shape = TensorShape[2].checked(pair(2, 3))
    assert_true(shape.is_ok())
    var made = ones[2](shape.payload.take())
    assert_true(made.is_ok())
    var tensor = made.payload.take()
    for i in range(2):
        for j in range(3):
            assert_true(tensor.set(pair(i, j), Float32(i * 3 + j)) == TensorStatus.OK)

    var reshape = interpret(source, Program([Op.reshape([3, 2], Order.C)], False))
    var reshape_dims = TensorShape[2].checked(pair(3, 2))
    assert_true(reshape_dims.is_ok())
    var reshaped = tensor.reshape_view[2](reshape_dims.payload.take())
    assert_true(reshaped.is_ok())
    var dense = reshaped.payload.take()
    for i in range(3):
        for j in range(2):
            var actual = dense.get(pair(i, j))
            assert_true(actual.is_ok())
            assert_equal(actual.payload.take(), Float32(reshape.cells[i * 2 + j].value))

    var transposed = tensor.transpose(0, 1)
    assert_true(transposed.is_ok())
    var intermediate = transposed.payload.take()
    var flipped = intermediate.flip(0)
    assert_true(flipped.is_ok())
    var view = flipped.payload.take()
    for i in range(3):
        for j in range(2):
            var cell = expected.cells[i * 2 + j]
            var actual = view.get(pair(i, j))
            var address = view.layout.physical_offset(pair(i, j))
            assert_true(actual.is_ok() and address.is_ok())
            assert_equal(actual.payload.take(), Float32(cell.value))
            assert_equal(address.payload.take(), cell.physical)

    var singleton = TensorShape[2].checked(pair(2, 1))
    assert_true(singleton.is_ok())
    var small = ones[2](singleton.payload.take())
    assert_true(small.is_ok())
    var singleton_tensor = small.payload.take()
    var target = TensorShape[2].checked(pair(2, 3))
    assert_true(target.is_ok())
    var expanded = singleton_tensor.broadcast_to[2](target.payload.take())
    assert_true(expanded.is_ok())
    var broadcast = expanded.payload.take()
    assert_equal(broadcast.layout.strides.get(1), 0)

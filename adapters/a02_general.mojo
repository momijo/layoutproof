# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: adapters/a02_general.mojo
# Module: adapters.a02_general

"""Read-only dependency adapter for Momijo's owned General FP32 tensor."""

from std.collections import List
from std.testing import assert_equal, assert_true
from layoutproof.a02 import Layout, Op, Order, Program
from layoutproof.a02.oracle import interpret
from momijo.tensor.shape.shape import RuntimeTensorShape
from momijo.tensor.factory.creation import ones_f32
from momijo.tensor.validation import TensorStatusCode


def check_general() raises:
    var source = Layout([2, 3], [3, 1], 0, 6, 0, True)
    var expected = interpret(source, Program([Op.reshape([3, 2], Order.C)], False))
    var shape = RuntimeTensorShape.try_from_dims(source.shape)
    assert_true(shape.is_ok())
    var made = ones_f32(shape.take_value())
    assert_true(made.is_ok())
    var tensor = made.take_value()
    for i in range(2):
        for j in range(3):
            assert_true(tensor.set([i, j], Float32(i * 3 + j)) == TensorStatusCode.OK)
    assert_true(tensor.reshape_in_place(expected.shape) == TensorStatusCode.OK)
    assert_equal(tensor.rank(), 2)
    assert_equal(tensor.numel(), len(expected.cells))
    for i in range(3):
        for j in range(2):
            var actual = tensor.get([i, j])
            assert_true(actual.is_ok())
            assert_equal(actual.take_value(), Float32(expected.cells[i * 2 + j].value))
    assert_true(tensor.reshape_in_place([4, 2]) == TensorStatusCode.SIZE_MISMATCH)
    assert_equal(tensor.numel(), len(expected.cells))

    var high_rank = List[Int](length=16, fill=1)
    high_rank[11] = 6
    assert_true(tensor.reshape_in_place(high_rank) == TensorStatusCode.OK)
    assert_equal(tensor.rank(), 16)
    var coordinate = List[Int](length=16, fill=0)
    coordinate[11] = 5
    var last = tensor.get(coordinate)
    assert_true(last.is_ok())
    assert_equal(last.take_value(), Float32(5))

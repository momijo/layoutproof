# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: adapters/a02_light.mojo
# Module: adapters.a02_light

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

    var copy_shape = TensorShape[2].checked(pair(3, 2))
    assert_true(copy_shape.is_ok())
    var copied = tensor.reshape_copy[2](copy_shape.payload.take())
    assert_true(copied.is_ok())
    var materialized = copied.payload.take()
    var disjoint = tensor.storage_regions_disjoint(materialized)
    assert_true(disjoint.is_ok() and disjoint.payload.take())
    assert_true(tensor.set(pair(0, 0), Float32(91)) == TensorStatus.OK)
    var copied_first = materialized.get(pair(0, 0))
    assert_true(copied_first.is_ok())
    assert_equal(copied_first.payload.take(), Float32(0))
    assert_true(materialized.set(pair(1, 1), Float32(71)) == TensorStatus.OK)
    var source_value = tensor.get(pair(1, 0))
    assert_true(source_value.is_ok())
    assert_equal(source_value.payload.take(), Float32(3))
    print("PASS: Momijo Light reshape copy uses disjoint storage and isolates writes")
    check_reversed_reshape()


def check_reversed_reshape() raises:
    var source = Layout([3], [-1], 2, 3, 0, False)
    var expected = interpret(source, Program([Op.reshape([1, 3], Order.C)], False))
    var dims = TensorShape[1].checked(StaticRankArray[1](3))
    assert_true(dims.is_ok())
    var made = ones[1](dims.payload.take())
    assert_true(made.is_ok())
    var owner = made.payload.take()
    for i in range(3):
        assert_true(owner.set(StaticRankArray[1](i), Float32(i + 1)) == TensorStatus.OK)
    var flipped = owner.flip(0)
    assert_true(flipped.is_ok())
    var reverse = flipped.payload.take()
    var target = TensorShape[2].checked(pair(1, 3))
    assert_true(target.is_ok())
    var reshaped = reverse.reshape_view[2](target.payload.value())
    assert_true(reshaped.is_ok())
    var view = reshaped.payload.take()
    for i in range(3):
        var index = pair(0, i)
        var offset = view.layout.physical_offset(index)
        var value = view.get(index)
        assert_true(offset.is_ok() and value.is_ok())
        assert_equal(offset.payload.take(), 2 - i)
        assert_equal(expected.cells[i].physical, 2 - i)
        assert_equal(value.payload.take(), Float32(3 - i))

    var strides = view.layout.strides
    var origin = view.layout.offset
    var writable = owner.mut_view()
    assert_true(writable.is_ok())
    var base = writable.payload.take()
    var selected = base.as_strided_mut_view[2](target.payload.value(), strides, origin)
    assert_true(selected.is_ok())
    var signed = selected.payload.take()
    assert_true(signed.set(pair(0, 0), Float32(91)) == TensorStatus.OK)
    assert_true(signed.set(pair(0, 1), Float32(71)) == TensorStatus.OK)
    for i in range(3):
        var readback = base.get(StaticRankArray[1](i))
        assert_true(readback.is_ok())
        assert_equal(readback.payload.take(), [Float32(1), Float32(71), Float32(91)][i])
    print("PASS: Momijo Light reverse reshape addresses and signed write-through")

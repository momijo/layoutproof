# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

"""Lower transforms to checked strided metadata and output-to-input maps."""

from std.collections import List, Optional
from .arithmetic import add, mul, count, decode, encode, dense, ordered_axis, validate
from .ir import Kind, Layout, Op, Order, Program


@fieldwise_init
struct AxisMap(ImplicitlyCopyable):
    var output_axis: Int  # -1 for a constant source coordinate
    var start: Int
    var step: Int


@fieldwise_init
struct Stage(Movable):
    var shape: List[Int]
    var axes: List[AxisMap]
    var reshape: Bool
    var order: Order

    def predecessor(self, output: List[Int], input_shape: List[Int]) raises -> List[Int]:
        if self.reshape:
            return decode(input_shape, encode(self.shape, output, self.order), self.order)
        var result = List[Int]()
        for axis in range(len(self.axes)):
            var rule = self.axes[axis]
            var value = rule.start
            if rule.output_axis >= 0:
                value = add(value, mul(rule.step, output[rule.output_axis]))
            result.append(value)
        return result^


@fieldwise_init
struct Lowered(Movable):
    var output: Layout
    var stages: List[Stage]

    def lineage(self, source: Layout, output: List[Int]) raises -> Int:
        var indices = output.copy()
        for i in range(len(self.stages) - 1, -1, -1):
            if i == 0:
                indices = self.stages[i].predecessor(indices, source.shape)
            else:
                indices = self.stages[i].predecessor(indices, self.stages[i - 1].shape)
        return encode(source.shape, indices, Order.C)


def lower_axes(input: List[Int], op: Op) raises -> Stage:
    var rank = len(input)
    var shape = input.copy()
    var axes = List[AxisMap]()
    for i in range(rank):
        axes.append(AxisMap(i, 0, 1))

    if op.kind == Kind.PERMUTE or op.kind == Kind.TRANSPOSE:
        var permutation = op.dims.copy()
        if op.kind == Kind.TRANSPOSE:
            if op.axis < 0 or op.axis >= rank or op.first < 0 or op.first >= rank:
                raise Error("transpose axis outside rank")
            permutation.clear()
            for i in range(rank):
                permutation.append(i)
            permutation[op.axis] = op.first
            permutation[op.first] = op.axis
        if len(permutation) != rank:
            raise Error("permutation rank mismatch")
        var seen = List[Bool](length=rank, fill=False)
        for i in range(rank):
            var source = permutation[i]
            if source < 0 or source >= rank or seen[source]:
                raise Error("invalid permutation")
            seen[source] = True
            axes[source] = AxisMap(i, 0, 1)
            shape[i] = input[source]
    elif op.kind == Kind.BROADCAST:
        shape = op.dims.copy()
        var shift = len(shape) - rank
        if shift < 0:
            raise Error("broadcast shrinks rank")
        for i in range(rank):
            var dst = i + shift
            if input[i] == 1:
                axes[i] = AxisMap(-1, 0, 0)
            else:
                if input[i] != shape[dst]:
                    raise Error("incompatible broadcast extent")
                axes[i] = AxisMap(dst, 0, 1)
    elif op.kind == Kind.EXPAND:
        if op.axis < 0 or op.axis > rank:
            raise Error("expand axis outside rank")
        shape.insert(op.axis, 1)
        for i in range(op.axis, rank):
            axes[i] = AxisMap(i + 1, 0, 1)
    elif op.kind == Kind.SQUEEZE:
        if op.axis < 0 or op.axis >= rank or input[op.axis] != 1:
            raise Error("squeeze requires singleton axis")
        _ = shape.pop(op.axis)
        axes[op.axis] = AxisMap(-1, 0, 0)
        for i in range(op.axis + 1, rank):
            axes[i] = AxisMap(i - 1, 0, 1)
    elif op.kind == Kind.SLICE or op.kind == Kind.FLIP:
        if op.axis < 0 or op.axis >= rank:
            raise Error("slice or flip axis outside rank")
        var extent = input[op.axis]
        var first = op.first
        var length = op.length
        var step = op.step
        if op.kind == Kind.FLIP:
            first = max(0, extent - 1)
            length = extent
            step = -1
        if step == 0 or length < 0 or first < 0 or first > extent:
            raise Error("invalid slice parameters")
        if length > 0:
            var last = add(first, mul(length - 1, step))
            if first == extent or last < 0 or last >= extent:
                raise Error("slice endpoint outside extent")
        shape[op.axis] = length
        axes[op.axis] = AxisMap(op.axis, first, step)
    else:
        raise Error("unknown operation")
    return Stage(shape^, axes^, False, Order.C)


def reshape_view_strides(source: Layout, target: List[Int], order: Order) raises -> List[Int]:
    var result = List[Int](length=len(target), fill=0)
    if count(target) <= 1:
        return result^
    var old_axes = List[Int]()
    var new_axes = List[Int]()
    for i in range(len(source.shape)):
        var axis = ordered_axis(len(source.shape), i, order)
        if source.shape[axis] > 1:
            old_axes.append(axis)
    for i in range(len(target)):
        var axis = ordered_axis(len(target), i, order)
        if target[axis] > 1:
            new_axes.append(axis)

    # A target dimension may split a linear block but cannot cross a stride break.
    var old = 0
    var new = 0
    while old < len(old_axes):
        var stride = source.strides[old_axes[old]]
        var block = source.shape[old_axes[old]]
        old += 1
        while old < len(old_axes):
            var axis = old_axes[old]
            if source.strides[axis] != mul(stride, block):
                break
            block = mul(block, source.shape[axis])
            old += 1
        var consumed = 1
        while consumed < block:
            if new >= len(new_axes):
                raise Error("reshape crosses a stride break")
            var axis = new_axes[new]
            result[axis] = mul(stride, consumed)
            consumed = mul(consumed, target[axis])
            new += 1
        if consumed != block:
            raise Error("reshape crosses a stride break")
    if new != len(new_axes):
        raise Error("reshape leaves unmatched axes")
    return result^


def lower_with_limits(source: Layout, program: Program, cell_limit: Int,
                      rank_limit: Int) raises -> Optional[Lowered]:
    var current = source.copy()
    var stages = List[Stage]()
    for index in range(len(program.ops)):
        ref op = program.ops[index]
        if op.kind == Kind.RESHAPE:
            if op.order != Order.C and op.order != Order.F:
                raise Error("unknown reshape order")
            var size = count(op.dims)
            if size != count(current.shape):
                raise Error("reshape element count mismatch")
            if op.materialize:
                current.storage = -1 - index
                current.capacity = size
                current.offset = 0
                current.write_capable = True
                current.strides = dense(op.dims, op.order)
            else:
                current.strides = reshape_view_strides(current, op.dims, op.order)
            current.shape = op.dims.copy()
            stages.append(Stage(op.dims.copy(), [], True, op.order))
        else:
            var stage = lower_axes(current.shape, op)
            var strides = List[Int](length=len(stage.shape), fill=0)
            if count(stage.shape) != 0:
                for i in range(len(stage.axes)):
                    var rule = stage.axes[i]
                    current.offset = add(current.offset, mul(current.strides[i], rule.start))
                    if rule.output_axis >= 0 and stage.shape[rule.output_axis] > 1:
                        strides[rule.output_axis] = mul(current.strides[i], rule.step)
            current.strides = strides^
            current.shape = stage.shape.copy()
            stages.append(stage^)
        validate(current)
        if len(current.shape) > rank_limit or count(current.shape) > cell_limit:
            return None
    return Lowered(current^, stages^)


def lower(source: Layout, program: Program) raises -> Lowered:
    var result = lower_with_limits(source, program, Int.MAX, Int.MAX)
    if not result:
        raise Error("unbounded lowering exhausted its limits")
    return result.take()

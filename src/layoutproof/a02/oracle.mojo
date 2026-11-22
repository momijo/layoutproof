# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

"""Independent bounded interpreter. Carries cells forward, never lowers strides."""

from std.collections import List
from .ir import Kind, Layout, Op, Order, Program
from .arithmetic import add, count, mul, validate


@fieldwise_init
struct Cell(ImplicitlyCopyable):
    var source: Int
    var value: Int  # root address names an arbitrary FP32 bit pattern
    var physical: Int


@fieldwise_init
struct Frame(Movable):
    var shape: List[Int]
    var cells: List[Cell]
    var storage: Int
    var write_capable: Bool


def cardinality(shape: List[Int]) -> Int:
    # The caller has established the bounded cardinality before evaluating.
    for extent in shape:
        if extent == 0:
            return 0
    var size = 1
    for extent in shape:
        size *= extent
    return size


def digits(shape: List[Int], n: Int) -> List[Int]:
    var index = List[Int](length=len(shape), fill=0)
    var remainder = n
    for axis in range(len(shape) - 1, -1, -1):
        index[axis] = remainder % shape[axis]
        remainder //= shape[axis]
    return index^


def row_number(shape: List[Int], index: List[Int]) -> Int:
    var n = 0
    for i in range(len(shape)):
        n = n * shape[i] + index[i]
    return n


def order_to_row(shape: List[Int], ordinal: Int, order: Order) -> Int:
    if order == Order.C:
        return ordinal
    var n = ordinal
    var index = List[Int]()
    for extent in shape:
        index.append(n % extent)
        n //= extent
    return row_number(shape, index)


def start(layout: Layout) -> Frame:
    var cells = List[Cell]()
    for n in range(cardinality(layout.shape)):
        var index = digits(layout.shape, n)
        var offset = layout.offset
        # Checked preflight established the min/max of every partial sum.
        for axis in range(len(index)):
            offset += index[axis] * layout.strides[axis]
        cells.append(Cell(n, offset, offset))
    return Frame(layout.shape.copy(), cells^, layout.storage, layout.write_capable)


def next_shape(input: List[Int], op: Op) -> List[Int]:
    var shape = List[Int]()
    if op.kind == Kind.RESHAPE or op.kind == Kind.BROADCAST:
        return op.dims.copy()
    if op.kind == Kind.PERMUTE:
        for axis in op.dims:
            shape.append(input[axis])
        return shape^
    for axis in range(len(input) + Int(op.kind == Kind.EXPAND)):
        if op.kind == Kind.EXPAND:
            if axis == op.axis:
                shape.append(1)
            else:
                shape.append(input[axis - Int(axis > op.axis)])
        elif op.kind == Kind.SQUEEZE and axis == op.axis:
            continue
        elif op.kind == Kind.TRANSPOSE and axis == op.axis:
            shape.append(input[op.first])
        elif op.kind == Kind.TRANSPOSE and axis == op.first:
            shape.append(input[op.axis])
        elif op.kind == Kind.SLICE and axis == op.axis:
            shape.append(op.length)
        else:
            shape.append(input[axis])
    return shape^


def lookup(input: List[Int], output: List[Int], index: List[Int], var n: Int, op: Op) -> Int:
    if op.kind == Kind.RESHAPE:
        if op.order == Order.F:
            n = 0
            for axis in range(len(output) - 1, -1, -1):
                n = n * output[axis] + index[axis]
        return order_to_row(input, n, op.order)
    var source = List[Int](length=len(input), fill=0)
    if op.kind == Kind.PERMUTE:
        for axis in range(len(index)):
            source[op.dims[axis]] = index[axis]
    else:
        for axis in range(len(source)):
            if op.kind == Kind.BROADCAST:
                if input[axis] != 1:
                    source[axis] = index[len(index) - len(input) + axis]
            elif op.kind == Kind.EXPAND:
                source[axis] = index[axis + Int(axis >= op.axis)]
            elif op.kind == Kind.SQUEEZE:
                if axis != op.axis:
                    source[axis] = index[axis - Int(axis > op.axis)]
            elif op.kind == Kind.TRANSPOSE and axis == op.axis:
                source[axis] = index[op.first]
            elif op.kind == Kind.TRANSPOSE and axis == op.first:
                source[axis] = index[op.axis]
            elif op.kind == Kind.SLICE and axis == op.axis:
                source[axis] = op.first + op.step * index[axis]
            elif op.kind == Kind.FLIP and axis == op.axis:
                source[axis] = input[axis] - 1 - index[axis]
            else:
                source[axis] = index[axis]
    return row_number(input, source)


def validate_step(input: List[Int], op: Op) raises:
    var rank = len(input)
    if op.kind == Kind.RESHAPE:
        if (op.order != Order.C and op.order != Order.F) or count(input) != count(op.dims):
            raise Error("invalid reshape order or size")
    elif op.kind == Kind.PERMUTE:
        if len(op.dims) != rank:
            raise Error("invalid permutation length")
        for axis in range(rank):
            if op.dims[axis] < 0 or op.dims[axis] >= rank:
                raise Error("permutation index outside rank")
            for previous in range(axis):
                if op.dims[axis] == op.dims[previous]:
                    raise Error("repeated permutation index")
    elif op.kind == Kind.BROADCAST:
        if len(op.dims) < rank:
            raise Error("broadcast shrinks rank")
        for axis in range(rank):
            if input[axis] != 1 and input[axis] != op.dims[len(op.dims) - rank + axis]:
                raise Error("invalid broadcast extent")
    elif op.kind == Kind.EXPAND:
        if op.axis < 0 or op.axis > rank:
            raise Error("invalid expand axis")
    else:
        if op.axis < 0 or op.axis >= rank:
            raise Error("axis outside rank")
        var extent = input[op.axis]
        if op.kind == Kind.SQUEEZE:
            if extent != 1:
                raise Error("squeeze requires a singleton")
        elif op.kind == Kind.TRANSPOSE:
            if op.first < 0 or op.first >= rank:
                raise Error("second transpose axis outside rank")
        elif op.kind == Kind.SLICE:
            if op.first < 0 or op.first > extent or op.length < 0 or op.step == 0:
                raise Error("invalid slice")
            if op.length > 0:
                if op.first == extent:
                    raise Error("slice starts past the last element")
                if op.step > 0:
                    if op.length - 1 > (extent - 1 - op.first) // op.step:
                        raise Error("slice reaches beyond extent")
                elif op.step == Int.MIN or op.length - 1 > op.first // -op.step:
                    if op.length > 1:
                        raise Error("slice reaches before origin")
        elif op.kind != Kind.FLIP:
            raise Error("unknown operation")


def fits(layout: Layout, program: Program, cap: Int) raises -> Bool:
    var shape = layout.shape.copy()
    for step in range(len(program.ops)):
        ref op = program.ops[step]
        validate_step(shape, op)
        shape = next_shape(shape, op)
        if len(shape) > 64 or count(shape) > cap:
            return False
    return True


def interpret(layout: Layout, program: Program, cap: Int = 256) raises -> Frame:
    if cap < 0 or cap > 4096 or len(layout.shape) > 64 or len(program.ops) > 64:
        raise Error("interpreter work limit")
    if layout.storage < 0:
        raise Error("invalid source storage identity")
    validate(layout)
    if count(layout.shape) > cap or not fits(layout, program, cap):
        raise Error("interpreter work limit")
    return interpret_bounded(layout, program)


def interpret_bounded(layout: Layout, program: Program) raises -> Frame:
    # Called only after fits and checked source validation.
    var frame = start(layout)
    for step in range(len(program.ops)):
        ref op = program.ops[step]
        var shape = next_shape(frame.shape, op)
        var cells = List[Cell]()
        var size = cardinality(shape)
        if op.kind == Kind.RESHAPE and size != len(frame.cells):
            raise Error("interpreter reshape count mismatch")
        var view_reshape = op.kind == Kind.RESHAPE and not op.materialize and size > 0
        var coefficients = List[Int]()
        var origin = 0
        if view_reshape:
            # Derive address coefficients from actual cells and check every
            # target coordinate, independently of the lowerer's block matching.
            origin = frame.cells[0].physical
            coefficients = List[Int](length=len(shape), fill=0)
            var unit = List[Int](length=len(shape), fill=0)
            for axis in range(len(shape)):
                if shape[axis] > 1:
                    unit[axis] = 1
                    var old = lookup(frame.shape, shape, unit, row_number(shape, unit), op)
                    coefficients[axis] = frame.cells[old].physical - origin
                    unit[axis] = 0
        for n in range(size):
            var index = digits(shape, n)
            var old = lookup(frame.shape, shape, index, n, op)
            var cell = frame.cells[old]
            if view_reshape:
                var expected = origin
                for axis in range(len(index)):
                    expected = add(expected, mul(index[axis], coefficients[axis]))
                if cell.physical != expected:
                    raise Error("interpreter reshape address map is not affine")
            if op.kind == Kind.RESHAPE and op.materialize:
                # Re-encode independently without using the lowering's dense strides.
                if op.order == Order.C:
                    cell.physical = n
                else:
                    var ordered = 0
                    var multiplier = 1
                    for axis in range(len(shape)):
                        ordered += index[axis] * multiplier
                        multiplier *= shape[axis]
                    cell.physical = ordered
            cells.append(cell)
        frame.shape = shape^
        frame.cells = cells^
        if op.kind == Kind.RESHAPE and op.materialize:
            frame.storage = -1 - step
            frame.write_capable = True
    return frame^


def first_alias(frame: Frame, peers: List[Layout]) -> Tuple[Int, Int]:
    # Lexicographically first conflicting C-order output cell/pair.
    var protected = List[Int]()
    for peer in peers:
        if peer.storage == frame.storage:
            var other = start(peer)
            for cell in other.cells:
                protected.append(cell.physical)
    for i in range(len(frame.cells)):
        for j in range(i + 1, len(frame.cells)):
            if frame.cells[i].physical == frame.cells[j].physical:
                return (i, j)
        for offset in protected:
            if offset == frame.cells[i].physical:
                return (i, -1)
    return (-1, -1)

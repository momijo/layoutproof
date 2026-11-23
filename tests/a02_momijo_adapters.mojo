# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT
# Source: tests/a02_momijo_adapters.mojo
# Module: tests.a02_momijo_adapters

from a02_general import check_general
from a02_light import check_light


def main() raises:
    check_general()
    print("PASS: Momijo General FP32 owned C-order reshape")
    check_light()
    print("PASS: Momijo Light FP32 transpose, negative stride and broadcast")

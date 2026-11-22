# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

from layoutproof.a02 import Layout, Program, Status
from layoutproof.a02.verifier import verify


def main() raises:
    var scalar = Layout([], [], 0, 1, 0, True)
    var identity = Program([], False)
    var verdict = verify(scalar, identity, identity, [])
    if verdict.status != Status.PASS:
        raise Error(verdict.detail)
    print("PASS: scalar layout smoke")

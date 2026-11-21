# SPDX-FileCopyrightText: 2026 Morteza Taleblou
# SPDX-FileCopyrightText: 2026 Mitra Daneshmand
# SPDX-License-Identifier: MIT

"""A02 tensor-layout research model and independently checked decisions."""
from .ir import Layout, Op, Order, Program, Checks, Status, Reason, Verdict
from .oracle import interpret
from .replay import Certificate, replay
from .solver import certify
from .verifier import replay_counterexample, verify
from .affine_replay import AffineCertificate, replay_affine, replay_affine_counterexample
from .affine_solver import certify_affine

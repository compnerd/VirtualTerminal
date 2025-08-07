// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension Duration {
  package var seconds: Double {
    return Double(components.seconds) + Double(components.attoseconds) / 1e18
  }

  package var nanoseconds: Int64 {
    return Int64(components.seconds) * 1_000_000_000 + Int64(components.attoseconds) / 1_000_000_000
  }
}

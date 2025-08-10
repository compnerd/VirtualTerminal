// Copyright © 2020 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

precedencegroup StreamOperatorPrecedence {
  associativity: left

  higherThan: AssignmentPrecedence
  lowerThan: NilCoalescingPrecedence
}

infix operator <<<: StreamOperatorPrecedence

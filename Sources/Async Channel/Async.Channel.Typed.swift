// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// ===----------------------------------------------------------------------===//

#if !hasFeature(Embedded)

    extension Async.Channel where Element: ~Copyable {
        public struct Typed<Failure: Swift.Error & Sendable> {}
    }

    extension Async.Channel.Typed where Element: ~Copyable, Failure: Swift.Error & Sendable {
        public typealias Error = _TypedChannelError<Failure>
    }

#endif

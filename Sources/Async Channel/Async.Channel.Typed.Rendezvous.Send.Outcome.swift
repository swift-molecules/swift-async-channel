// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// ===----------------------------------------------------------------------===//

#if !hasFeature(Embedded)

    extension Async.Channel.Typed.Rendezvous.Send where Element: ~Copyable, Failure: Swift.Error & Sendable {
        public enum Outcome: ~Copyable {
            case sent

            case rejected(Element, Async.Channel<Element>.Typed<Failure>.Error)
        }
    }

#endif

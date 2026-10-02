// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// ===----------------------------------------------------------------------===//

#if !hasFeature(Embedded)

    extension Async.Channel.Typed where Element: ~Copyable, Failure: Swift.Error & Sendable {
        @frozen
        public struct Rendezvous: ~Copyable, Sendable {
            @usableFromInline let storage: Storage

            public let sender: Sender

            public var receiver: Receiver

            public init() {
                let storage = Storage()
                self.storage = storage
                self.sender = Sender(storage: storage)
                self.receiver = Receiver(storage: storage)
            }
        }
    }

#endif

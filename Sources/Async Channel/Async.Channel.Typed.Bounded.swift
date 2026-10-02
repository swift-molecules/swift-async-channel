// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// ===----------------------------------------------------------------------===//

#if !hasFeature(Embedded)

    public import Index

    extension Async.Channel.Typed where Element: ~Copyable, Failure: Swift.Error & Sendable {
        @frozen
        public struct Bounded: ~Copyable, Sendable {
            @usableFromInline let terminals: TerminalStorage

            public let sender: Sender

            public var receiver: Receiver

            public init(capacity: Index<Element>.Count) {
                var raw = Async.Channel<Element>.Bounded(capacity: capacity)
                let terminals = TerminalStorage()
                self.terminals = terminals
                self.sender = Sender(raw: raw.sender, terminals: terminals)
                self.receiver = Receiver(
                    raw: consume raw.receiver,
                    closer: raw.sender,
                    terminals: terminals
                )
            }
        }
    }

#endif

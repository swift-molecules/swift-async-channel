// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// ===----------------------------------------------------------------------===//

#if !hasFeature(Embedded)

    public enum _TypedChannelError<Failure: Swift.Error & Sendable>: Swift.Error, Sendable {
        case closed

        case cancelled

        case full

        case empty

        case finished

        case failed(Failure)
    }

    extension _TypedChannelError {
        @usableFromInline
        init<Element>(terminal: Async.Channel<Element>.Typed<Failure>.Terminal) where Element: ~Copyable {
            switch terminal {
            case .finished: self = .finished
            case .failed(let failure): self = .failed(failure)
            }
        }

        @usableFromInline
        init<Element>(
            raw: Async._ChannelError,
            terminal: Async.Channel<Element>.Typed<Failure>.Terminal?
        ) where Element: ~Copyable {
            switch terminal {
            case let terminal?: self.init(terminal: terminal)
            case nil:
                switch raw {
                case .closed: self = .closed
                case .cancelled: self = .cancelled
                case .full: self = .full
                case .empty: self = .empty
                }
            }
        }
    }

#endif

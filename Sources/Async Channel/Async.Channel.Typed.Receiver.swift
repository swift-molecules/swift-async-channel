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
        public struct Receiver: ~Copyable, Sendable {
            @usableFromInline let raw: Async.Channel<Element>.Bounded.Receiver
            @usableFromInline let closer: Async.Channel<Element>.Bounded.Sender
            @usableFromInline let terminals: TerminalStorage

            @usableFromInline
            init(
                raw: consuming Async.Channel<Element>.Bounded.Receiver,
                closer: Async.Channel<Element>.Bounded.Sender,
                terminals: TerminalStorage
            ) {
                self.raw = raw
                self.closer = closer
                self.terminals = terminals
            }
        }
    }

    extension Async.Channel.Typed.Receiver where Element: ~Copyable, Failure: Swift.Error & Sendable {
        public func receive() async throws(Async.Channel<Element>.Typed<Failure>.Error) -> sending Element? {
            do throws(Async._ChannelError) {
                if let element = try await raw.receive() {
                    return element
                }
            } catch {
                throw Async.Channel<Element>.Typed<Failure>.Error(raw: error, terminal: terminals.terminal(from: .sender))
            }

            if case .failed(let failure)? = terminals.terminal(from: .sender) {
                throw .failed(failure)
            }
            return nil
        }

        public func finish() {
            guard terminals.install(.finished, from: .receiver) else { return }
            closer.close()
        }

        public func fail(_ failure: consuming Failure) {
            guard terminals.install(.failed(consume failure), from: .receiver) else { return }
            closer.close()
        }
    }

#endif

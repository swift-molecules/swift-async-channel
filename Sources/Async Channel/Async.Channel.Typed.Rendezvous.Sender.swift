// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// ===----------------------------------------------------------------------===//

#if !hasFeature(Embedded)

    public import Memory_Allocator_Protocol
    public import Async_Waiter
    public import Ownership
    public import Deque
    public import Memory
    public import Memory_Allocator
    public import Storage
    public import Buffer
    public import Buffer_Ring_Primitive

    extension Async.Channel.Typed.Rendezvous where Element: ~Copyable, Failure: Swift.Error & Sendable {
        public struct Sender: Sendable {
            @usableFromInline let storage: Storage

            @usableFromInline
            init(storage: Storage) {
                self.storage = storage
            }
        }
    }

    extension Async.Channel.Typed.Rendezvous.Sender where Element: ~Copyable, Failure: Swift.Error & Sendable {
        @usableFromInline
        final class Waiter: Sendable {
            @usableFromInline typealias Continuation = Async.Continuation<Signal>.Unsafe
            @usableFromInline let element: Ownership.Slot<Element>
            @usableFromInline let continuation: Ownership.Slot<Continuation>
            @usableFromInline let flag: Async.Waiter.Flag

            @usableFromInline
            init(_ element: consuming sending Element) {
                self.element = Ownership.Slot(consume element)
                self.continuation = Ownership.Slot()
                self.flag = Async.Waiter.Flag()
            }
        }

        @usableFromInline
        enum Signal: Sendable {
            case sent
            case rejected(Async.Channel<Element>.Typed<Failure>.Error)
        }

        public func send(_ element: consuming sending Element) async -> Async.Channel<Element>.Typed<Failure>.Rendezvous.Send.Outcome {
            let waiter = Waiter(consume element)

            let signal: Signal = await withTaskCancellationHandler {
                await unsafe withUnsafeContinuation { (raw: UnsafeContinuation<Signal, Never>) in
                    let continuation = unsafe Async.Continuation.Unsafe(raw)
                    _ = waiter.continuation.store(continuation)
                    var terminal: Async.Channel<Element>.Typed<Failure>.Terminal?
                    var cancelledSelf = false
                    var cancelled = Deque<Buffer<Storage::Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Async.Channel<Element>.Typed<Failure>.Rendezvous.Receiver.Waiter>>.Ring>()
                    let receiver = storage.withLock { state -> Async.Channel<Element>.Typed<Failure>.Rendezvous.Receiver.Waiter? in
                        if waiter.flag.isFlagged {
                            cancelledSelf = true
                            return nil
                        }
                        if let installed = state.receiverTerminal ?? state.senderTerminal {
                            terminal = installed
                            return nil
                        }
                        while let candidate = state.receivers.take(from: .front) {
                            if candidate.flag.isFlagged {
                                cancelled.push(candidate, to: .back)
                                continue
                            }
                            return candidate
                        }
                        state.senders.push(waiter, to: .back)
                        return nil
                    }
                    while let receiver = cancelled.take(from: .front) {
                        receiver.continuation.take()?.resume(returning: .cancelled)
                    }
                    if cancelledSelf {
                        waiter.continuation.take()?.resume(returning: .rejected(.cancelled))
                    } else if let terminal {
                        waiter.continuation.take()?.resume(returning: .rejected(Async.Channel<Element>.Typed<Failure>.Error(terminal: terminal)))
                    }
                    if let receiver {
                        let value = waiter.element.take(__unchecked: ())
                        _ = receiver.element.store(consume value)
                        receiver.continuation.take(__unchecked: ()).resume(returning: .delivered)
                        waiter.continuation.take(__unchecked: ()).resume(returning: .sent)
                    }
                }
            } onCancel: {
                guard waiter.flag.cancel() else { return }
                let removed = storage.withLock { state -> Waiter? in
                    var survivors = Deque<Buffer<Storage::Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Waiter>>.Ring>()
                    var removed: Waiter?
                    while let candidate = state.senders.take(from: .front) {
                        if candidate === waiter {
                            removed = candidate
                        } else {
                            survivors.push(candidate, to: .back)
                        }
                    }
                    state.senders = consume survivors
                    return removed
                }
                removed?.continuation.take()?.resume(returning: .rejected(.cancelled))
            }

            switch signal {
            case .sent:
                return .sent
            case .rejected(let error):
                return .rejected(waiter.element.take(__unchecked: ()), error)
            }
        }

        public func finish() {
            terminate(.finished)
        }

        public func fail(_ failure: consuming Failure) {
            terminate(.failed(consume failure))
        }

        @usableFromInline
        func terminate(_ terminal: Async.Channel<Element>.Typed<Failure>.Terminal) {
            var receivers = Deque<Buffer<Storage::Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Async.Channel<Element>.Typed<Failure>.Rendezvous.Receiver.Waiter>>.Ring>()
            var senders = Deque<Buffer<Storage::Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Waiter>>.Ring>()
            storage.withLock { state in
                guard state.senderTerminal == nil else { return }
                state.senderTerminal = terminal
                Swift.swap(&receivers, &state.receivers)
                Swift.swap(&senders, &state.senders)
            }
            while let receiver = receivers.take(from: .front) {
                receiver.continuation.take()?.resume(returning: .terminal(terminal))
            }
            while let sender = senders.take(from: .front) {
                sender.continuation.take()?.resume(returning: .rejected(Async.Channel<Element>.Typed<Failure>.Error(terminal: terminal)))
            }
        }
    }

#endif

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
        @usableFromInline
        struct State: ~Copyable {
            @usableFromInline var senderTerminal: Async.Channel<Element>.Typed<Failure>.Terminal?
            @usableFromInline var receiverTerminal: Async.Channel<Element>.Typed<Failure>.Terminal?
            @usableFromInline var senders: Deque<Buffer<Storage::Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Sender.Waiter>>.Ring>
            @usableFromInline var receivers: Deque<Buffer<Storage::Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Receiver.Waiter>>.Ring>

            @usableFromInline
            init() {
                senderTerminal = nil
                receiverTerminal = nil
                senders = Deque()
                receivers = Deque()
            }
        }
    }

#endif

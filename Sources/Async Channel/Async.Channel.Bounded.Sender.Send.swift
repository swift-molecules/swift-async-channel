#if !hasFeature(Embedded)

    public import Ownership
    import Buffer
    import Buffer_Linear_Primitive
    import Buffer_Linear_Bounded_Primitive
    import Buffer_Ring_Primitive
    import Memory_Allocator_Pool
    import Memory_Pool
    import Memory_Allocator
    import Memory
    import Ownership_Shared_Primitive
    import Storage
    import Store

    extension Async.Channel.Bounded.Sender where Element: ~Copyable {

        public struct Send: Sendable {
            @usableFromInline
            let handle: Handle

            @usableFromInline
            init(handle: Handle) {
                self.handle = handle
            }

            @_optimize(none)
            @inlinable
            public func immediate(
                _ element: consuming sending Element
            ) throws(Async.Channel<Element>.Error) {
                let slot = Ownership.Slot(consume element)
                let decision = handle.storage.withLock { state in
                    state.send(slot)
                }

                switch consume decision {
                case .deliverToReceiver(let receiverCont, let element):
                    _ = handle.storage.deliverySlot.store(element)
                    receiverCont.resume(
                        returning: Async.Channel<Element>.Bounded.State.Receive.Signal.delivered
                    )

                case .buffered:
                    break

                case .rejectClosed:
                    throw .closed

                case .suspend:
                    throw .full
                }
            }
        }
    }

#endif

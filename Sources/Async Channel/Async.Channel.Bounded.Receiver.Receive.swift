#if !hasFeature(Embedded)

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
    public import Buffer_Ring_Primitive
    public import Storage
    public import Deque

    extension Async.Channel.Bounded.Receiver where Element: ~Copyable {

        public struct Receive: Sendable {
            @usableFromInline
            let storage: Async.Channel<Element>.Bounded.Storage

            @usableFromInline
            init(storage: Async.Channel<Element>.Bounded.Storage) {
                self.storage = storage
            }

            @_optimize(none)
            @inlinable
            public func immediate() throws(Async.Channel<Element>.Error) -> Element? {
                let action = storage.withLock { state in
                    state.receive()
                }

                switch consume action {
                case .returnElement(let element, let resumeSender, var cancelled, _):

                    while let c = cancelled?.take(from: .front) {
                        c.resume(returning: .cancelled)
                    }
                    resumeSender?.resume(returning: nil)
                    return element

                case .returnNil:
                    return nil

                case .rejectCancelled:
                    throw .cancelled

                case .suspend:
                    throw .empty
                }
            }
        }
    }

#endif

#if !hasFeature(Embedded)

    extension Async.Channel.Bounded where Element: ~Copyable {

        public struct Ends: ~Copyable, Sendable {
            public let sender: Sender

            @usableFromInline
            var _receiver: Receiver

            @usableFromInline
            init(sender: Sender, receiver: consuming Receiver) {
                self.sender = sender
                self._receiver = receiver
            }
        }
    }

    extension Async.Channel.Bounded.Ends where Element: ~Copyable {

        public var receiver: Async.Channel<Element>.Bounded.Receiver {
            _read {
                yield _receiver
            }
            _modify {
                yield &_receiver
            }
        }

        public func close() {
            sender.close()
        }

        public var isClosed: Bool {
            sender.isClosed
        }
    }

#endif

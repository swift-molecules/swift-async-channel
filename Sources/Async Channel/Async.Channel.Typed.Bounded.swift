#if !hasFeature(Embedded)

    public import Index

    extension Async.Channel.Typed where Element: ~Copyable, Failure: Swift::Error & Sendable {
        @frozen
        public struct Bounded: ~Copyable, Sendable {
            @usableFromInline let terminals: TerminalStorage

            public let sender: Sender

            public var receiver: Receiver

            public init(capacity: Index<Element>.Count) {
                let raw = Async.Channel<Element>.Bounded(capacity: capacity)
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

#if !hasFeature(Embedded)

    public import Pair

    extension Async.Channel.Typed.Rendezvous where Element: ~Copyable, Failure: Swift::Error & Sendable {
        @frozen
        public struct Duplex: ~Copyable, Sendable {
            public let outbound: Sender
            public var inbound: Receiver

            @usableFromInline
            init(outbound: Sender, inbound: consuming Receiver) {
                self.outbound = outbound
                self.inbound = consume inbound
            }

            public static func pair() -> Pair<Self, Self> {
                let leftToRight = Async.Channel<Element>.Typed<Failure>.Rendezvous()
                let rightToLeft = Async.Channel<Element>.Typed<Failure>.Rendezvous()
                return Pair(
                    Self(outbound: leftToRight.sender, inbound: consume rightToLeft.receiver),
                    Self(outbound: rightToLeft.sender, inbound: consume leftToRight.receiver)
                )
            }

            public func shutdown() {
                outbound.finish()
                inbound.finish()
            }
        }
    }

#endif

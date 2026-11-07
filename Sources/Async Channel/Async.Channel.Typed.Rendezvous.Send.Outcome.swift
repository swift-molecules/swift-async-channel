#if !hasFeature(Embedded)

    extension Async.Channel.Typed.Rendezvous.Send where Element: ~Copyable, Failure: Swift::Error & Sendable {
        public enum Outcome: ~Copyable {
            case sent

            case rejected(Element, Async.Channel<Element>.Typed<Failure>.Error)
        }
    }

#endif

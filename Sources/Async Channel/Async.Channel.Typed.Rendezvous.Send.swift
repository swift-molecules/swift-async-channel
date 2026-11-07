#if !hasFeature(Embedded)

    extension Async.Channel.Typed.Rendezvous where Element: ~Copyable, Failure: Swift::Error & Sendable {
        public enum Send {}
    }

#endif

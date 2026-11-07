#if !hasFeature(Embedded)

    extension Async.Channel where Element: ~Copyable {
        public struct Typed<Failure: Swift::Error & Sendable> {}
    }

    extension Async.Channel.Typed where Element: ~Copyable, Failure: Swift::Error & Sendable {
        public typealias Error = _TypedChannelError<Failure>
    }

#endif

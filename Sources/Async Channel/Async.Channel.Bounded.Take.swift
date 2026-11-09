#if !hasFeature(Embedded)

    extension Async.Channel.Bounded where Element: ~Copyable {

        public struct Take: ~Copyable, Sendable {
            @usableFromInline
            var channel: Async.Channel<Element>.Bounded

            @usableFromInline
            init(channel: consuming Async.Channel<Element>.Bounded) {
                self.channel = channel
            }

            public consuming func ends() -> Ends {
                let sender = channel.sender
                let receiver = consume channel.receiver
                return Ends(sender: sender, receiver: receiver)
            }
        }
    }

#endif

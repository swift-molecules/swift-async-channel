# swift-async-channel

Use this package to hand elements, including `~Copyable` and non-`Sendable` ones, from any number of producers to exactly one consumer. Start from `Async.Channel<Element>.Bounded` when producers must slow down to the consumer's pace, and from `Async.Channel<Element>.Unbounded` when a send must never wait. Start from `Async.Channel<Element>.Typed<Failure>.Bounded` when either side must end the conversation with its own typed failure, and from `Async.Channel<Element>.Typed<Failure>.Rendezvous` when a send should complete only once a receiver has taken the element. `Async.Channel<Element>.Typed<Failure>.Rendezvous.Duplex` pairs two rendezvous channels for two-way traffic. To deliver every element to many consumers, use swift-async-broadcast instead. To transform or combine sequences, use swift-async-stream.

## Laws

Untyped channels (`Async.Channel<Element>.Bounded`, `Async.Channel<Element>.Unbounded`):

- Elements arrive in the order they were sent. A receiver that is already waiting gets the element directly, without it passing through the buffer.
- Closing is idempotent. After close, sends throw `.closed`. Elements buffered before the close are still delivered, and receive returns `nil` only once the buffer is drained.
- A receive that finds a buffered element returns it even if its task is cancelled. Cancellation throws `.cancelled` only where the receive would otherwise wait.
- Bounded: a send buffers while fewer than `capacity` elements are buffered, and otherwise suspends. Suspended senders are admitted one per received element, oldest first. Close resumes every suspended sender with `.closed`. A cancelled suspended send throws `.cancelled`. In both cases the element is not delivered.
- Bounded: `Async.Channel<Element>.Bounded.Sender.Send` and `Async.Channel<Element>.Bounded.Receiver.Receive` never suspend. They throw `.full` and `.empty` where `send` and `receive` would wait.
- Bounded: releasing every copy of the channel's `sender` closes the channel. The receiver still drains what was buffered.
- Unbounded: dropping senders never closes the channel. Only `close()` does.
- Unbounded: `send(contentsOf:)` enqueues the whole batch in order under one lock. It enqueues all of it or, if the channel is already closed, none of it.
- Unbounded: `poll()` never waits. It returns buffered elements also after close, and returns `nil` whenever nothing is buffered, so `nil` does not tell an empty channel from a closed one.
- Unbounded: two `Async.Channel<Element>.Unbounded.Sender` values are equal exactly when they feed the same channel, also after close.

Typed channels (`Async.Channel<Element>.Typed<Failure>`):

- Each direction installs at most one terminal. The first `finish()` or `fail(_:)` on a side wins, and later calls on that side do nothing.
- A send reports the receiver's terminal ahead of the sender's own. A receive reports the sender's terminal ahead of the receiver's own.
- A sender's `finish()` makes receives return `nil`, and its `fail(_:)` makes them throw `.failed` with that exact failure. After the receiver's own `finish()`, receive returns `nil` and sends throw `.finished`.
- With no terminal installed, cancellation is reported as `.cancelled`.
- Bounded: buffered elements drain before the sender's terminal is reported. Once a terminal is installed, a send or receive that fails with `.closed` or `.cancelled` reports that terminal instead. The receiver keeps the channel open, so it ends only through `finish()` or `fail(_:)`, never by dropping senders. A rejected send drops its element.
- Rendezvous: a cancelled operation reports `.cancelled` even when a terminal is installed. Nothing is buffered. `.sent` means a receiver now owns the element. Every rejection, including cancellation before pairing, hands the element back in `.rejected`. Once pairing has happened, delivery wins over a later cancellation.
- Rendezvous: waiting senders and waiting receivers are paired oldest first. A cancelled waiter is removed without disturbing the others. A sender terminal wakes every waiting receiver and rejects every waiting sender. A receiver terminal rejects every waiting sender.
- Duplex: in `pair()`, the first value's `outbound` feeds the second value's `inbound`, and the other way round. Finishing `outbound` closes only that direction. `shutdown()` finishes both of the value's own directions.

import Async_Channel
import Async
import Testing

extension `Async channel benchmarks preserve delivery under repeated execution` {
    @Suite struct `Bounded channels preserve delivery under repeated execution` {}
}

extension `Async channel benchmarks preserve delivery under repeated execution`.`Bounded channels preserve delivery under repeated execution` {

    @Test(.timed(iterations: 10, warmup: 2))
    func `1000 round-trips capacity 1`() async throws {
        let channel = Async.Channel<Int>.Bounded(capacity: 1)
        let sender = channel.sender

        let producer = Task.detached {
            for i in 0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations {
                try await sender.send(i)
            }
        }

        for _ in 0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations {
            _ = try await channel.receiver.receive()
        }

        _ = try await producer.value
    }

    @Test(.timed(iterations: 10, warmup: 2))
    func `1000 round-trips capacity 1000`() async throws {
        let channel = Async.Channel<Int>.Bounded(capacity: 1_000)
        let sender = channel.sender

        let producer = Task.detached {
            for i in 0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations {
                try await sender.send(i)
            }
        }

        for _ in 0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations {
            _ = try await channel.receiver.receive()
        }

        _ = try await producer.value
    }

    @Test(.timed(iterations: 10, warmup: 2))
    func `1000 immediate sends capacity 1000`() async throws {
        let channel = Async.Channel<Int>.Bounded(capacity: 1_000)
        let sender = channel.sender

        let producer = Task.detached {
            for i in 0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations {
                try sender.send.immediate(i)
            }
        }

        for _ in 0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations {
            _ = try await channel.receiver.receive()
        }

        _ = try await producer.value
    }
}

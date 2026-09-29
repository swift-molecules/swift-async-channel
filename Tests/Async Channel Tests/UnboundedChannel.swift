import Async_Channel
import Async
import Ownership
import Tagged
import Testing

extension `Async channel benchmarks preserve delivery under repeated execution` {
    @Suite struct `Unbounded channels preserve delivery under repeated execution` {}
}

extension `Async channel benchmarks preserve delivery under repeated execution`.`Unbounded channels preserve delivery under repeated execution` {

    @Test
    func `Unbounded channels deliver 1000 values in one batch`() async throws {
        let ends = Async.Channel<Int>.Unbounded().take().ends()
        let elements = Array(0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations)

        try ends.sender.send(contentsOf: elements.map { Ownership.Slot($0) })
        ends.close()

        var count = 0
        while try await ends.receiver.receive() != nil { count += 1 }
        #expect(count == `Async channel benchmarks preserve delivery under repeated execution`.iterations)
    }

    @Test
    func `Unbounded channels deliver 1000 individually sent values`() async throws {
        let ends = Async.Channel<Int>.Unbounded().take().ends()

        for i in 0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations {
            try ends.sender.send(i)
        }
        ends.close()

        var count = 0
        while try await ends.receiver.receive() != nil { count += 1 }
        #expect(count == `Async channel benchmarks preserve delivery under repeated execution`.iterations)
    }
}

extension `Async channel benchmarks preserve delivery under repeated execution`.`Unbounded channels preserve delivery under repeated execution` {

    @Test
    func `Unbounded channels preserve 1000 single value round trips`() async throws {
        let ends = Async.Channel<Int>.Unbounded().take().ends()

        let producer = Task.detached {
            for i in 0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations {
                try ends.sender.send(i)
            }
        }

        for _ in 0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations {
            _ = try await ends.receiver.receive()
        }

        _ = try await producer.value
        ends.close()
    }

    @Test
    func `Unbounded channels preserve 1000 batch round trips`() async throws {
        let ends = Async.Channel<Int>.Unbounded().take().ends()
        let started = Async.Barrier(parties: 2)

        let receiver = Task {
            await started.arrive()
            var count = 0
            while try await ends.receiver.receive() != nil { count += 1 }
            return count
        }

        await started.arrive()
        let elements = Array(0..<`Async channel benchmarks preserve delivery under repeated execution`.iterations)
        try ends.sender.send(contentsOf: elements.map { Ownership.Slot($0) })
        ends.close()

        let count = try await receiver.value
        #expect(count == `Async channel benchmarks preserve delivery under repeated execution`.iterations)
    }
}

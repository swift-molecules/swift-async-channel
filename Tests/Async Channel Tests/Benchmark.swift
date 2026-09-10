import Async_Channel
import Async
import Testing

@Suite(.serialized)
struct `Async channel benchmarks preserve delivery under repeated execution` {
    static let iterations = 1_000
}

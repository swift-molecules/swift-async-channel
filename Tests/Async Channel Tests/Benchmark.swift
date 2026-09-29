import Async_Channel
import Async
import Tagged
import Testing

@Suite(.serialized)
struct `Async channel benchmarks preserve delivery under repeated execution` {
    static let iterations = 1_000
}

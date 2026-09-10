import Async
import Async_Channel
import Testing

@Suite
struct `Async channels retain the shared async namespace` {

    @Test
    func `Async channel declarations retain the shared namespace`() {
        _ = Async.self
        _ = Async.Channel<Never>.self
    }
}

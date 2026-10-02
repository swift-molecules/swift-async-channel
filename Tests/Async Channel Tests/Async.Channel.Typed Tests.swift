// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// ===----------------------------------------------------------------------===//


@testable import Async_Channel
import Deque
import Pair
import Tagged
import Async
import Async_Barrier
import Testing

@Suite
struct `Typed channels preserve terminal identity and handoff` {
    enum Failure: Swift.Error, Sendable, Equatable {
        case stopped(Int)
    }

    struct Token: ~Copyable, Sendable {
        let value: Int
    }

    @Test
    func `sender sends and finishes receiver`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)

        try await channel.sender.send(42)
        channel.sender.finish()

        #expect(try await channel.receiver.receive() == 42)
        #expect(try await channel.receiver.receive() == nil)
    }

    @Test
    func `sender failure preserves buffered drain and identity`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 2)

        try await channel.sender.send(1)
        channel.sender.fail(.stopped(2))

        #expect(try await channel.receiver.receive() == 1)
        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            _ = try await channel.receiver.receive()
            Issue.record("Expected sender failure after the buffered drain")
        } catch {
            switch error {
            case .failed(.stopped(2)):
                break
            default:
                Issue.record("Expected the sender's declared failure")
            }
        }
    }

    @Test
    func `receiver failure propagates to sender`() async {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)

        channel.receiver.fail(.stopped(3))

        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            try await channel.sender.send(1)
            Issue.record("Expected receiver failure to reject the sender")
        } catch {
            switch error {
            case .failed(.stopped(3)):
                break
            default:
                Issue.record("Expected the receiver's declared failure")
            }
        }
    }

    @Test
    func `first terminal operation wins`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)

        channel.sender.fail(.stopped(4))
        channel.sender.finish()

        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            _ = try await channel.receiver.receive()
            Issue.record("Expected the first terminal failure")
        } catch {
            switch error {
            case .failed(.stopped(4)):
                break
            default:
                Issue.record("Expected the first terminal operation to win")
            }
        }
    }

    @Test
    func `typed sender retains bounded backpressure`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        let sender = channel.sender
        let gate = Async.Barrier(parties: 2)

        try await sender.send(1)
        let blocked = Task {
            try? await gate.arrive()
            try await sender.send(2)
        }

        try? await gate.arrive()
        #expect(try await channel.receiver.receive() == 1)
        try await blocked.value
        #expect(try await channel.receiver.receive() == 2)
    }

    @Test
    func `receiver failure resumes a backpressured sender with the same failure`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        let sender = channel.sender
        let gate = Async.Barrier(parties: 2)

        try await sender.send(1)
        let blocked = Task { () -> Async.Channel<Int>.Typed<Failure>.Error? in
            try? await gate.arrive()
            do throws(Async.Channel<Int>.Typed<Failure>.Error) {
                try await sender.send(2)
                return nil
            } catch {
                return error
            }
        }

        try? await gate.arrive()
        channel.receiver.fail(.stopped(5))

        let result = await blocked.value
        switch result {
        case .some(.failed(.stopped(5))):
            break
        default:
            Issue.record("Expected receiver failure to resume the blocked sender")
        }
    }

    @Test
    func `cancelling a backpressured sender preserves cancellation`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        let sender = channel.sender
        let gate = Async.Barrier(parties: 2)

        try await sender.send(1)
        let blocked = Task { () -> Async.Channel<Int>.Typed<Failure>.Error? in
            try? await gate.arrive()
            do throws(Async.Channel<Int>.Typed<Failure>.Error) {
                try await sender.send(2)
                return nil
            } catch {
                return error
            }
        }

        try? await gate.arrive()
        blocked.cancel()

        let result = await blocked.value
        switch result {
        case .some(.cancelled):
            break
        default:
            Issue.record("Expected cancellation to remain distinct from terminal failure")
        }
    }

    @Test
    func `rendezvous pairs sender first without storing an element`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        let sender = channel.sender
        let sending = Task {
            switch await sender.send(1) {
            case .sent: return true
            case .rejected: return false
            }
        }

        #expect(try await channel.receiver.receive() == 1)
        #expect(await sending.value)
    }

    @Test
    func `rendezvous pairs receiver first`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        let sender = channel.sender
        let receiver = consume channel.receiver
        let receiving = Task { try await receiver.receive() }

        switch await sender.send(2) {
        case .sent: break
        case .rejected: Issue.record("Expected direct receiver handoff")
        }
        #expect(try await receiving.value == 2)
    }

    @Test
    func `rendezvous preserves FIFO sender pairing`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        let sender = channel.sender
        let storage = sender.storage
        let first = Task {
            switch await sender.send(1) { case .sent: true; case .rejected: false }
        }
        var spins = 0
        while storage.withLock({ $0.senders.isEmpty }) && spins < 1_000_000 {
            spins += 1
            await Task.yield()
        }
        let firstEnqueued = !storage.withLock { $0.senders.isEmpty }
        #expect(firstEnqueued)
        let second = Task {
            switch await sender.send(2) { case .sent: true; case .rejected: false }
        }
        spins = 0
        while storage.withLock({ $0.senders.count != 2 }) && spins < 1_000_000 {
            spins += 1
            await Task.yield()
        }
        let bothEnqueued = storage.withLock { $0.senders.count == 2 }
        #expect(bothEnqueued)

        #expect(try await channel.receiver.receive() == 1)
        #expect(try await channel.receiver.receive() == 2)
        #expect(await first.value)
        #expect(await second.value)
    }

    @Test
    func `rendezvous cancellation returns the unpaired sender element`() async {
        var channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        let sender = channel.sender
        let receiver = consume channel.receiver
        let task = Task { () -> Int? in
            switch await sender.send(3) {
            case .sent: return nil
            case .rejected(let element, .cancelled): return element
            case .rejected: return nil
            }
        }
        task.cancel()
        #expect(await task.value == 3)
    }

    @Test
    func `rendezvous receiver cancellation removes only that waiter`() async {
        var channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        let receiver = consume channel.receiver
        let task = Task { try await receiver.receive() }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected receiver cancellation")
        } catch {
            guard case .cancelled? = error as? Async.Channel<Int>.Typed<Failure>.Error else {
                Issue.record("Expected cancellation identity, got \(error)")
                return
            }
        }
    }

    @Test
    func `rendezvous terminal wakes waiters and preserves exact failure`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        let sender = channel.sender
        let waiting = Task { () -> (Int, Failure?) in
            switch await sender.send(4) {
            case .sent: return (0, nil)
            case .rejected(let element, .failed(let failure)): return (element, failure)
            case .rejected(let element, _): return (element, nil)
            }
        }
        channel.receiver.fail(.stopped(7))

        let (element, failure) = await waiting.value
        #expect(element == 4)
        #expect(failure == .stopped(7))

        channel.sender.fail(.stopped(8))
        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            _ = try await channel.receiver.receive()
            Issue.record("Expected sender failure")
        } catch {
            if case .failed(.stopped(8)) = error {} else { Issue.record("Expected exact sender failure") }
        }
    }

    @Test
    func `rendezvous duplex half close and shutdown remain directional`() async throws {
        let duplexes = Async.Channel<Int>.Typed<Failure>.Rendezvous.Duplex.pair()
        let outbound = duplexes.first.outbound
        let sending = Task { () -> Bool in
            switch await outbound.send(5) {
            case .sent: true
            case .rejected: false
            }
        }
        #expect(try await duplexes.second.inbound.receive() == 5)
        #expect(await sending.value, "Expected duplex handoff")
        duplexes.first.outbound.finish()
        #expect(try await duplexes.second.inbound.receive() == nil)
        duplexes.second.shutdown()
    }

    @Test
    func `rendezvous transfers a move only element exactly once`() async throws {
        var channel = Async.Channel<Token>.Typed<Failure>.Rendezvous()
        let sender = channel.sender
        let sending = Task {
            switch await sender.send(Token(value: 9)) {
            case .sent: return true
            case .rejected: return false
            }
        }
        guard let token = try await channel.receiver.receive() else {
            Issue.record("Expected move-only token")
            return
        }
        let value = token.value
        #expect(value == 9)
        #expect(await sending.value)
    }
}

extension `Typed channels preserve terminal identity and handoff` {
    final class Tracker: Sendable {
        let drops = Async.Mutex(0)
        var count: Int { drops.withLock { $0 } }
    }

    struct Tracked: ~Copyable, Sendable {
        let value: Int
        let tracker: Tracker
        deinit { tracker.drops.withLock { $0 += 1 } }
    }

    static func sendError(
        _ sender: Async.Channel<Int>.Typed<Failure>.Sender,
        _ value: Int
    ) async -> Async.Channel<Int>.Typed<Failure>.Error? {
        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            try await sender.send(value)
            return nil
        } catch {
            return error
        }
    }

    static func rendezvousOutcome(
        _ sender: Async.Channel<Int>.Typed<Failure>.Rendezvous.Sender,
        _ value: Int
    ) async -> (Int, Async.Channel<Int>.Typed<Failure>.Error)? {
        switch await sender.send(value) {
        case .sent: return nil
        case .rejected(let element, let error): return (element, error)
        }
    }

    @Test
    func `bounded send after own normal finish reports finished`() async {
        let channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        channel.sender.finish()
        guard case .finished? = await Self.sendError(channel.sender, 1) else {
            Issue.record("Expected .finished after the sender's own finish")
            return
        }
    }

    @Test
    func `bounded send after own failure reports the exact failure`() async {
        let channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        channel.sender.fail(.stopped(20))
        guard case .failed(.stopped(20))? = await Self.sendError(channel.sender, 1) else {
            Issue.record("Expected .failed(.stopped(20)) after the sender's own failure")
            return
        }
    }

    @Test
    func `bounded send prefers the receiver terminal when both directions are terminal`() async {
        let channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        channel.receiver.fail(.stopped(21))
        channel.sender.fail(.stopped(22))
        guard case .failed(.stopped(21))? = await Self.sendError(channel.sender, 1) else {
            Issue.record("Expected the receiver terminal to take priority for the sender")
            return
        }
    }

    @Test
    func `bounded receive prefers the sender terminal when both directions are terminal`() async {
        let channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        channel.receiver.fail(.stopped(23))
        channel.sender.fail(.stopped(24))
        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            _ = try await channel.receiver.receive()
            Issue.record("Expected the sender terminal")
        } catch {
            if case .failed(.stopped(24)) = error {} else { Issue.record("Expected .failed(.stopped(24))") }
        }
    }

    @Test
    func `bounded receive after own finish with no sender terminal ends`() async throws {
        let channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        channel.receiver.finish()
        #expect(try await channel.receiver.receive() == nil)
        guard case .finished? = await Self.sendError(channel.sender, 1) else {
            Issue.record("Expected the receiver's finish to reject the sender with .finished")
            return
        }
    }

    @Test
    func `rendezvous send after own normal finish reports finished and returns the element`() async {
        let channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        channel.sender.finish()
        guard case (30, .finished)? = await Self.rendezvousOutcome(channel.sender, 30) else {
            Issue.record("Expected .rejected(30, .finished)")
            return
        }
    }

    @Test
    func `rendezvous send after own failure reports the exact failure and returns the element`() async {
        let channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        channel.sender.fail(.stopped(31))
        guard case (32, .failed(.stopped(31)))? = await Self.rendezvousOutcome(channel.sender, 32) else {
            Issue.record("Expected .rejected(32, .failed(.stopped(31)))")
            return
        }
    }

    @Test
    func `rendezvous both terminals keep opposite direction priority`() async {
        let channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        channel.receiver.fail(.stopped(33))
        channel.sender.fail(.stopped(34))
        guard case (35, .failed(.stopped(33)))? = await Self.rendezvousOutcome(channel.sender, 35) else {
            Issue.record("Expected the receiver terminal for the sender")
            return
        }
        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            _ = try await channel.receiver.receive()
            Issue.record("Expected the sender terminal for the receiver")
        } catch {
            if case .failed(.stopped(34)) = error {} else { Issue.record("Expected .failed(.stopped(34))") }
        }
    }

    @Test
    func `terminal state installs once per direction`() async {
        let channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        channel.receiver.finish()
        channel.receiver.fail(.stopped(36))
        guard case (37, .finished)? = await Self.rendezvousOutcome(channel.sender, 37) else {
            Issue.record("Expected the first receiver terminal to remain installed")
            return
        }
    }

    @Test
    func `rendezvous handoff transfers a tracked element exactly once`() async throws {
        let tracker = Tracker()
        var channel = Async.Channel<Tracked>.Typed<Failure>.Rendezvous()
        let sender = channel.sender
        let sending = Task {
            switch await sender.send(Tracked(value: 40, tracker: tracker)) {
            case .sent: return true
            case .rejected: return false
            }
        }
        guard let token = try await channel.receiver.receive() else {
            Issue.record("Expected the tracked element")
            return
        }
        #expect(await sending.value)
        #expect(tracker.count == 0)
        let value = token.value
        _ = consume token
        #expect(value == 40)
        #expect(tracker.count == 1)
    }

    @Test
    func `rendezvous rejection returns a tracked element exactly once`() async {
        let tracker = Tracker()
        let channel = Async.Channel<Tracked>.Typed<Failure>.Rendezvous()
        channel.receiver.fail(.stopped(41))
        switch await channel.sender.send(Tracked(value: 42, tracker: tracker)) {
        case .sent:
            Issue.record("Expected rejection")
        case .rejected(let element, let error):
            #expect(tracker.count == 0)
            let value = element.value
            _ = consume element
            #expect(value == 42)
            if case .failed(.stopped(41)) = error {} else { Issue.record("Expected .failed(.stopped(41))") }
        }
        #expect(tracker.count == 1)
    }

    @Test
    func `rendezvous cancellation before pairing returns a tracked element exactly once`() async {
        let tracker = Tracker()
        let channel = Async.Channel<Tracked>.Typed<Failure>.Rendezvous()
        let sender = channel.sender
        let task = Task { () -> Int? in
            switch await sender.send(Tracked(value: 43, tracker: tracker)) {
            case .sent: return nil
            case .rejected(let element, .cancelled): return element.value
            case .rejected: return nil
            }
        }
        task.cancel()
        #expect(await task.value == 43)
        #expect(tracker.count == 1)
    }

    @Test
    func `bounded buffered tracked element is delivered exactly once after normal finish`() async throws {
        let tracker = Tracker()
        let channel = Async.Channel<Tracked>.Typed<Failure>.Bounded(capacity: 1)
        try await channel.sender.send(Tracked(value: 44, tracker: tracker))
        channel.sender.finish()
        guard let token = try await channel.receiver.receive() else {
            Issue.record("Expected the buffered tracked element")
            return
        }
        #expect(tracker.count == 0)
        let value = token.value
        _ = consume token
        #expect(value == 44)
        #expect(tracker.count == 1)
        guard try await channel.receiver.receive() == nil else {
            Issue.record("Expected the end after the buffered element")
            return
        }
        #expect(tracker.count == 1)
    }

    @Test
    func `bounded rejected send consumes a tracked element exactly once`() async {
        let tracker = Tracker()
        let channel = Async.Channel<Tracked>.Typed<Failure>.Bounded(capacity: 1)
        channel.sender.fail(.stopped(45))
        do throws(Async.Channel<Tracked>.Typed<Failure>.Error) {
            try await channel.sender.send(Tracked(value: 46, tracker: tracker))
            Issue.record("Expected rejection")
        } catch {
            if case .failed(.stopped(45)) = error {} else { Issue.record("Expected .failed(.stopped(45))") }
        }
        #expect(tracker.count == 1)
    }

    @Test
    func `rendezvous cancellation of an already enqueued sender removes the waiter and returns the element`() async {
        let tracker = Tracker()
        let channel = Async.Channel<Tracked>.Typed<Failure>.Rendezvous()
        let sender = channel.sender
        let storage = sender.storage
        let task = Task { () -> Int? in
            switch await sender.send(Tracked(value: 50, tracker: tracker)) {
            case .sent: return nil
            case .rejected(let element, .cancelled): return element.value
            case .rejected: return nil
            }
        }
        var spins = 0
        while storage.withLock({ $0.senders.isEmpty }) && spins < 1_000_000 {
            spins += 1
            await Task.yield()
        }
        let enqueued = !storage.withLock { $0.senders.isEmpty }
        #expect(enqueued)
        task.cancel()
        #expect(await task.value == 50)
        let removed = storage.withLock { $0.senders.isEmpty }
        #expect(removed)
        #expect(tracker.count == 1)
    }

    @Test
    func `rendezvous cancellation of an already enqueued receiver removes the waiter`() async {
        var channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        let storage = channel.sender.storage
        let receiver = consume channel.receiver
        let task = Task { () -> Async.Channel<Int>.Typed<Failure>.Error? in
            do throws(Async.Channel<Int>.Typed<Failure>.Error) {
                _ = try await receiver.receive()
                return nil
            } catch {
                return error
            }
        }
        var spins = 0
        while storage.withLock({ $0.receivers.isEmpty }) && spins < 1_000_000 {
            spins += 1
            await Task.yield()
        }
        let enqueued = !storage.withLock { $0.receivers.isEmpty }
        #expect(enqueued)
        task.cancel()
        guard case .cancelled? = await task.value else {
            Issue.record("Expected .cancelled for the enqueued receiver")
            return
        }
        let removed = storage.withLock { $0.receivers.isEmpty }
        #expect(removed)
    }

    @Test
    func `rendezvous delivery wins over cancellation once pairing has happened`() async {
        var channel = Async.Channel<Int>.Typed<Failure>.Rendezvous()
        let sender = channel.sender
        let storage = sender.storage
        let receiver = consume channel.receiver
        let receiving = Task { () -> Int? in
            do throws(Async.Channel<Int>.Typed<Failure>.Error) {
                return try await receiver.receive()
            } catch {
                return nil
            }
        }
        var spins = 0
        while storage.withLock({ $0.receivers.isEmpty }) && spins < 1_000_000 {
            spins += 1
            await Task.yield()
        }
        let enqueued = !storage.withLock { $0.receivers.isEmpty }
        #expect(enqueued)
        switch await sender.send(51) {
        case .sent: break
        case .rejected: Issue.record("Expected pairing with the enqueued receiver")
        }
        receiving.cancel()
        #expect(await receiving.value == 51)
    }
}

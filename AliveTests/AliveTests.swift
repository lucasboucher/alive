import Foundation
import Testing
@testable import Alive

struct StatusTransitionTests {
    @Test func losingTheInterfaceIsImmediate() {
        var transition = StatusModel.Transition(state: .online, consecutiveFailures: 1)
        transition.apply(hasInterface: false, reachable: nil)
        #expect(transition.state == .offline)
        #expect(transition.consecutiveFailures == 0)
    }

    @Test func oneFailureKeepsTheCurrentState() {
        var transition = StatusModel.Transition(state: .online, consecutiveFailures: 0)
        transition.apply(hasInterface: true, reachable: false)
        #expect(transition.state == .online)
        #expect(transition.consecutiveFailures == 1)
    }

    @Test func twoFailuresShowNoInternet() {
        var transition = StatusModel.Transition(state: .online, consecutiveFailures: 1)
        transition.apply(hasInterface: true, reachable: false)
        #expect(transition.state == .noInternet)
        #expect(transition.consecutiveFailures == 2)
    }

    @Test func successResetsTheStreak() {
        var transition = StatusModel.Transition(state: .noInternet, consecutiveFailures: 2)
        transition.apply(hasInterface: true, reachable: true)
        #expect(transition.state == .online)
        #expect(transition.consecutiveFailures == 0)
    }
}

struct CaptiveResponseTests {
    @Test func successBodyIsReachable() {
        #expect(StatusModel.isCaptiveSuccess(Data("Success".utf8)))
    }

    @Test func portalBodyIsNotReachable() {
        #expect(!StatusModel.isCaptiveSuccess(Data("<html>portail</html>".utf8)))
    }

    @Test func emptyBodyIsNotReachable() {
        #expect(!StatusModel.isCaptiveSuccess(Data()))
    }
}

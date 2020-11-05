import Combine
@testable import CombineFeedback
import XCTest

class CombineFeedbackTests: XCTestCase {
    var disposable: Cancellable!

    func test_emits_initial() {
        let initial = "initial"
        var result = [String]()

        let system = Publishers.system(
            initial: initial,
            feedbacks: [],
            reduce: .init { state, event in
                state += event
            }
        )

        disposable = system.sink {
            result.append($0)
        }

        XCTAssertEqual(result, ["initial"])
    }

    func test_reducer_with_one_feedback_loop() {
        let feedback = Feedback<String, String>.middleware { _ in
            Just("_a")
        }
        let system = Publishers.system(
            initial: "initial",
            feedbacks: [feedback],
            reduce: .init { (state, event) in
                state += event
            }
        )

        var result: [String] = []
        disposable = system.output(in: 0...3).collect()
            .sink {
                result = $0
            }


        let expected = [
            "initial",
            "initial_a",
            "initial_a_a",
            "initial_a_a_a",
        ]
        XCTAssertEqual(result, expected)
    }

    func test_reduce_with_two_immediate_feedback_loops() {
        let feedback1 = Feedback<String, String>.middleware { state -> AnyPublisher<String, Never> in
            if state == "initial" || state.hasSuffix("b") {
                return Just("_a").eraseToAnyPublisher()
            } else {
                return Empty().eraseToAnyPublisher()
            }
        }
        let feedback2 = Feedback<String, String>.middleware { state -> AnyPublisher<String, Never> in
            if state.hasSuffix("a") {
                return Just("_b").eraseToAnyPublisher()
            } else {
                return Empty().eraseToAnyPublisher()
            }
        }
        let system = Publishers.system(
            initial: "initial",
            feedbacks: [feedback1, feedback2],
            reduce: .init { (state, event) in
                print("Event a \(event)")
                state += event
            }
        )
        var results: [String] = []

        let cancel = system.output(in: 0...5).collect().sink {
            results = $0
        }

        let expected = [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_a",
            "initial_a_b_a_b",
            "initial_a_b_a_b_a",
        ]

        XCTAssertEqual(results, expected)
        cancel.cancel()
    }

    func test_should_observe_signals_immediately() {
        let input = Feedback<String, String>.input
        let system = Publishers.system(
            initial: "initial",
            feedbacks: [
                input.feedback,
            ],
            reduce: .init { (state, event) in
                print("Event b \(event)")
                state += event
            }
        )

        var results: [String] = []

        let cancel = system.sink(
            receiveValue: {
                results.append($0)
            }
        )

        XCTAssertEqual(["initial"], results)
        input.observer("_a")
        XCTAssertEqual(["initial", "initial_a"], results)
        cancel.cancel()
    }
    
    func test_cancelation() {
        let input = Feedback<String, String>.input
        let system = Publishers.system(
            initial: "initial",
            feedbacks: [
                input.feedback,
            ],
            reduce: .init { (state, event) in
                state += event
            }
        )

        var results: [String] = []
        let cancel = system.sink(
            receiveValue: {
                results.append($0)
            }
        )

        XCTAssertEqual(["initial"], results)
        input.observer("_a")
        input.observer("_b")
        cancel.cancel()
        input.observer("_c")
        XCTAssertEqual(["initial", "initial_a", "initial_a_b"], results)
    }
}

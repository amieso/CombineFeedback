import XCTest
@testable import CombineFeedbackUI

class CombineFeedbackUITests: XCTestCase {
    class TestStore: Store<Bool, Void> {
        var onDeinit: (() -> ())?
        deinit {
            onDeinit?()
        }
    }

    func testSomething() {
        var sut: TestStore? = TestStore(initial: false, feedbacks: [], reducer: .init(reduce: { _,_  in }))
        var didDeinit = false
        weak var context: Context<Bool, Void>?
        context = sut?.context

        sut?.onDeinit = {
            context = nil
            didDeinit = true
        }
        autoreleasepool {
            sut = nil
        }


        XCTAssertTrue(didDeinit)
        XCTAssertNil(context)
    }
}

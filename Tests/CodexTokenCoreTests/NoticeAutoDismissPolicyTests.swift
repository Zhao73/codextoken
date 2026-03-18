import XCTest
@testable import CodexTokenCore

final class NoticeAutoDismissPolicyTests: XCTestCase {
    func testSuccessNoticeWithoutActionDismissesAfterFiveSeconds() {
        XCTAssertEqual(
            NoticeAutoDismissPolicy.delay(
                for: .success,
                hasAction: false
            ),
            5
        )
    }

    func testInfoNoticeWithoutActionDismissesAfterFiveSeconds() {
        XCTAssertEqual(
            NoticeAutoDismissPolicy.delay(
                for: .info,
                hasAction: false
            ),
            5
        )
    }

    func testErrorNoticeDoesNotAutoDismiss() {
        XCTAssertNil(
            NoticeAutoDismissPolicy.delay(
                for: .error,
                hasAction: false
            )
        )
    }

    func testActionableNoticeDoesNotAutoDismiss() {
        XCTAssertNil(
            NoticeAutoDismissPolicy.delay(
                for: .success,
                hasAction: true
            )
        )
    }
}

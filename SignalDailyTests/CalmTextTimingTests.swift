import XCTest
@testable import SignalDaily

final class CalmTextTimingTests: XCTestCase {
    func testLetterDelayStaggersQuicklyAndCaps() {
        XCTAssertEqual(CalmTextTiming.letterDelay(index: 0), 0)
        XCTAssertEqual(CalmTextTiming.letterDelay(index: 5), 0.06, accuracy: 0.0001)
        XCTAssertEqual(CalmTextTiming.letterDelay(index: 100), 0.22, accuracy: 0.0001)
    }

    func testLetterDelaySupportsFastScrollCadence() {
        XCTAssertEqual(CalmTextTiming.letterDelay(index: 10, step: 0.006, maximum: 0.08), 0.06, accuracy: 0.0001)
        XCTAssertEqual(CalmTextTiming.letterDelay(index: 20, step: 0.006, maximum: 0.08), 0.08, accuracy: 0.0001)
    }

    func testBriefingStatusTextKeepsSummaryCompact() {
        XCTAssertEqual(BriefingStatusText.progress(read: 0, total: 18), "0 of 18 read")
        XCTAssertEqual(BriefingStatusText.depthTokens(remaining: 3, allowed: 3), "3/3")
    }

    func testMainFeedQueueSummaryStaysCalmAndNonCommercial() {
        let text = BriefingStatusText.queueSummary(
            cardCount: 18,
            readingTimeMinutes: 9
        )

        XCTAssertEqual(text, "18 cards · 9 min")
        XCTAssertFalse(text.localizedCaseInsensitiveContains("depth"))
        XCTAssertFalse(text.contains("£"))
    }

    func testCardOrdinalUsesEditorialNumbering() {
        XCTAssertEqual(BriefingStatusText.cardOrdinal(index: 1, total: 2), "01 / 02")
        XCTAssertEqual(BriefingStatusText.cardOrdinal(index: 12, total: 18), "12 / 18")
    }

    func testGlassDeckLayoutMakesCardsReadAsSwipeableCards() {
        XCTAssertGreaterThanOrEqual(GlassDeckLayout.cardWidthRatio, 0.94)
        XCTAssertLessThanOrEqual(GlassDeckLayout.cardWidthRatio, 0.96)
        XCTAssertGreaterThan(GlassDeckLayout.activeScale, 1.0)
        XCTAssertLessThanOrEqual(GlassDeckLayout.inactiveScale, 0.96)
        XCTAssertLessThan(GlassDeckLayout.inactiveOpacity, 0.8)
        XCTAssertGreaterThanOrEqual(GlassDeckLayout.topOffset, 4)
        XCTAssertLessThanOrEqual(GlassDeckLayout.topOffset, 20)
        XCTAssertTrue(GlassDeckLayout.showsSwipeCue)
        XCTAssertEqual(GlassDeckLayout.swipeCueDotCount, 3)
        XCTAssertFalse(GlassDeckLayout.showsQueueLabel)
        XCTAssertFalse(GlassDeckLayout.showsQueueSummary)
        XCTAssertFalse(GlassDeckLayout.showsCardOrdinal)
    }

    func testSwipeCueHighlightFollowsFocusedStoryIndex() {
        XCTAssertEqual(GlassDeckLayout.swipeCueActiveDotIndex(focusedIndex: 0, total: 38), 0)
        XCTAssertEqual(GlassDeckLayout.swipeCueActiveDotIndex(focusedIndex: 1, total: 38), 1)
        XCTAssertEqual(GlassDeckLayout.swipeCueActiveDotIndex(focusedIndex: 2, total: 38), 2)
        XCTAssertEqual(GlassDeckLayout.swipeCueActiveDotIndex(focusedIndex: 3, total: 38), 0)
        XCTAssertEqual(GlassDeckLayout.swipeCueActiveDotIndex(focusedIndex: 9, total: 1), 0)
    }

    func testSavedEmptyStateSitsLowerOnThePage() {
        XCTAssertGreaterThanOrEqual(SavedStoriesLayout.emptyStateTopPadding, 60)
        XCTAssertLessThanOrEqual(SavedStoriesLayout.emptyStateTopPadding, 100)
    }

    func testTopBarReservesMatchingSpaceForCenteredTitle() {
        XCTAssertEqual(SignalTopBarLayout.controlSize, 36)
    }

    func testLibraryTabIsAvailableForClearedStories() {
        XCTAssertTrue(AppTab.allCases.contains(.done))
        XCTAssertEqual(AppTab.done.title, "Library")
        XCTAssertEqual(AppTab.done.systemImage, "books.vertical")
    }

    func testMonthlySubscriptionUsesNinetyNinePenceFallbackCopy() {
        XCTAssertEqual(SignalSubscriptionProduct.monthly, "the_brief_monthly")
        XCTAssertEqual(SubscriptionCopy.title, "The Brief Plus")
        XCTAssertEqual(SubscriptionCopy.monthlyPriceFallback, "£0.99 / month")
    }

    func testMainFeedActionsUsePlainCalmLabels() {
        XCTAssertEqual(BriefingStatusText.moreInformationAction, "More information")
        XCTAssertEqual(BriefingStatusText.doneAction, "Done")
        XCTAssertEqual(BriefingStatusText.commentAction, "Comment")
    }

    func testPopupInformationIsGroupedBeforeDetailHeavySections() {
        XCTAssertEqual(BriefingStatusText.atAGlanceTitle, "At a glance")
        XCTAssertEqual(BriefingStatusText.evidenceTitle, "Evidence and uncertainty")
        XCTAssertEqual(BriefingStatusText.framingTitle, "Framing and sources")
        XCTAssertTrue(PopupArticleLayout.usesSummaryForLead)
        XCTAssertFalse(PopupArticleLayout.leadSectionUsesInnerCard)
        XCTAssertFalse(PopupArticleLayout.reportedDetailStartsExpanded)
        XCTAssertGreaterThanOrEqual(PopupArticleLayout.maxChromeWidth, 360)
        XCTAssertGreaterThanOrEqual(PopupArticleLayout.bodyLineSpacing, 4)
    }

    func testPopupCopyStripsRawHTMLAndEntities() {
        let raw = #"<article><h2>UAE paid &amp; reported</h2><p>Source&nbsp;copy &#39;quoted&#39;</p></article>"#

        XCTAssertEqual(
            PopupCopy.cleaned(raw),
            "UAE paid & reported Source copy 'quoted'"
        )
    }

    func testAuthScreenUsesBorderlessOuterLayout() {
        XCTAssertFalse(AuthLayout.usesOuterCardBorder)
        XCTAssertEqual(AuthLayout.horizontalPadding, 20)
        XCTAssertFalse(AuthLayout.usesManualAppleAuthorizationController)
        XCTAssertTrue(AuthLayout.showsBuildNumberOnAuthScreen)
        XCTAssertTrue(AuthLayout.usesNativeSwiftUIAppleButton)
        XCTAssertFalse(AuthLayout.usesBrowserAppleAsPrimary)
        XCTAssertFalse(AuthLayout.showsBrowserAppleFallback)
    }
}

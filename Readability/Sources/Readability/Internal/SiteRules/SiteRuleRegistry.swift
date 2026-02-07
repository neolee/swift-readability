import Foundation
import SwiftSoup

enum SiteRuleRegistry {
    static func applyArticleCleanerRules(
        _ rules: [ArticleCleanerSiteRule.Type],
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        for rule in rules {
            try rule.apply(to: articleContent, context: context)
        }
    }

    static func applySerializationRules(to articleContent: Element) throws {
        let rules: [SerializationSiteRule.Type] = [
            TelegraphCaptionOnlyFigureRule.self,
            CityLabHeadlineTimestampRule.self,
            BuzzFeedLeadImageSuperlistRule.self,
            ArsIntroHeaderWrapperRule.self,
            FirefoxNightlyHeaderPlaceholderRule.self
        ]
        for rule in rules {
            try rule.apply(to: articleContent)
        }
    }

    static func applyUnwantedElementRules(
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        let rules: [ArticleCleanerSiteRule.Type] = [
            WashingtonPostGalleryEmbedRule.self,
            YahooSlideshowModalRule.self,
            BBCVideoPlaceholderRule.self,
            NYTimesLivePanelsRule.self,
            SeattleTimesSectionRailRule.self,
            NYTimesContinueReadingWrapperRule.self,
            WashingtonPostViewGraphicPromoRule.self,
            CNNLegacyStoryTopRule.self,
            MedicalNewsTodayRelatedInlineRule.self,
            CNETPlaylistOverlayRule.self,
            CityLabPromoSignupRule.self,
            EngadgetSlideshowIconRule.self,
            FirefoxNightlyCommentFormRule.self,
            MozillaCustomizeSyncSectionRule.self
        ]
        try applyArticleCleanerRules(rules, to: articleContent, context: context)
    }

    static func applyPreConversionRules(
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        let rules: [ArticleCleanerSiteRule.Type] = [
            NYTimesRelatedLinkCardsRule.self
        ]
        try applyArticleCleanerRules(rules, to: articleContent, context: context)
    }

    static func applyShareRules(
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        let rules: [ArticleCleanerSiteRule.Type] = [
            GuardianShareElementsRule.self
        ]
        try applyArticleCleanerRules(rules, to: articleContent, context: context)
    }

    static func applyPostProcessRules(
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        let rules: [ArticleCleanerSiteRule.Type] = [
            NYTimesCollectionHighlightsRule.self,
            NYTimesSpanishCardSummaryRule.self,
            NYTimesPhotoViewerWrapperRule.self,
            EngadgetBuyLinkRule.self,
            EngadgetBreakoutTypeRule.self,
            EngadgetReviewSummaryWrapperRule.self,
            TheVergeZoomWrapperAccessibilityRule.self
        ]
        try applyArticleCleanerRules(rules, to: articleContent, context: context)
    }

    static func applyPostParagraphRules(
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        let rules: [ArticleCleanerSiteRule.Type] = [
            NYTimesSplitPrintInfoRule.self
        ]
        try applyArticleCleanerRules(rules, to: articleContent, context: context)
    }
}

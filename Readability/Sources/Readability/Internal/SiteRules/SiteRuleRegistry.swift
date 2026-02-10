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
            FirefoxNightlyHeaderPlaceholderRule.self,
            WikipediaMathDisplayBlockRule.self,
            EHowFoundHelpfulHeaderRule.self,
            QQVoteContainerRule.self
        ]
        for rule in rules {
            try rule.apply(to: articleContent)
        }
    }

    static func applyBylineRules(
        _ byline: String?,
        sourceURL: URL?,
        document: Document
    ) throws -> String? {
        let rules: [BylineSiteRule.Type] = [
            HeraldSunUppercaseBylineRule.self,
            YahooBylineTimeRule.self,
            RoyalRoadFollowAuthorBylineRule.self,
            TumblrBlogHandleBylineRule.self,
            WikiaBylineTimeSuffixRule.self
        ]
        var current = byline
        for rule in rules {
            current = try rule.apply(byline: current, sourceURL: sourceURL, document: document)
        }
        return current
    }

    static func shouldKeepBylineContainer(
        _ node: Element,
        sourceURL: URL?,
        document: Document
    ) throws -> Bool {
        let rules: [BylineContainerRetentionSiteRule.Type] = [
            EHowAuthorProfileBylineRetentionRule.self
        ]
        for rule in rules {
            if try rule.shouldKeepBylineContainer(node, sourceURL: sourceURL, document: document) {
                return true
            }
        }
        return false
    }

    static func applyUnwantedElementRules(
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        let rules: [ArticleCleanerSiteRule.Type] = [
            WashingtonPostGalleryEmbedRule.self,
            YahooSlideshowModalRule.self,
            YahooBreakingNewsModuleRule.self,
            BBCVideoPlaceholderRule.self,
            AktualneTwitterEmbedRule.self,
            AktualneInlinePhotoRule.self,
            QQSharePanelRule.self,
            HeraldSunReadMoreLinkRule.self,
            LiberationRelatedAsideRule.self,
            LiberationAuthorsContainerRule.self,
            NYTimesLivePanelsRule.self,
            SeattleTimesSectionRailRule.self,
            NYTimesContinueReadingWrapperRule.self,
            WashingtonPostViewGraphicPromoRule.self,
            CNNLegacyStoryTopRule.self,
            MedicalNewsTodayRelatedInlineRule.self,
            CNETPlaylistOverlayRule.self,
            CityLabPromoSignupRule.self,
            EngadgetSlideshowIconRule.self,
            WikipediaLeadMetaNoiseRule.self,
            FirefoxNightlyCommentFormRule.self,
            MozillaCustomizeSyncSectionRule.self,
            EHowAuthorProfileRule.self,
            SimplyFoundMediaContainerRule.self,
            FolhaGalleryWidgetRule.self,
            PixnetArticleKeywordRule.self
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
            YahooStoryContainerRule.self,
            CityLabPromoSummarySectionRule.self,
            TheVergeZoomWrapperAccessibilityRule.self,
            LiberationArticleBodyWrapperRule.self,
            WordPressPrevNextNavigationRule.self
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

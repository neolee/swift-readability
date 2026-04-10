import Foundation
import SwiftSoup

enum SiteRuleRegistry {
    struct SiblingInclusionDecision {
        let ruleID: String
        let include: Bool
    }

    struct SiblingExtractionResult {
        let ruleID: String
        let element: Element
    }

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
            AntirezProsePreRule.self,
            TelegraphCaptionOnlyFigureRule.self,
            CityLabHeadlineTimestampRule.self,
            BuzzFeedLeadImageSuperlistRule.self,
            ArsIntroHeaderWrapperRule.self,
            FirefoxNightlyHeaderPlaceholderRule.self,
            WikipediaGovernmentPortraitCaptionRule.self,
            WikipediaMathDisplayBlockRule.self,
            EHowFoundHelpfulHeaderRule.self,
            QQVoteContainerRule.self,
            BreitbartHeaderMediaRule.self,
            QuantaTopReactIDRule.self,
            HukumusumeLegacyFileURLRule.self
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
            WebMDBylineRule.self,
            QuantaBylineDateRule.self,
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

    static func applyMetadataBylineRules(
        _ byline: String?,
        sourceURL: URL?,
        document: Document
    ) throws -> String? {
        let rules: [MetadataBylineSiteRule.Type] = [
            AntirezBylineRule.self,
            FirefoxNightlyBylineRule.self
        ]
        var current = byline
        for rule in rules {
            current = try rule.apply(currentByline: current, sourceURL: sourceURL, document: document)
        }
        return current
    }

    static func applyExcerptRules(
        _ excerpt: String?,
        articleContent: Element,
        sourceURL: URL?,
        document: Document
    ) throws -> String? {
        let rules: [ExcerptSiteRule.Type] = [
            AntirezExcerptRule.self
        ]
        var current = excerpt
        for rule in rules {
            current = try rule.apply(
                currentExcerpt: current,
                articleContent: articleContent,
                sourceURL: sourceURL,
                document: document
            )
        }
        return current
    }

    static func promotedCandidate(from candidate: Element) -> Element? {
        let rules: [CandidatePromotionSiteRule.Type] = [
            QuantaLeadCandidatePromotionRule.self,
            BreitbartArticleCandidatePromotionRule.self,
            FirefoxNightlyContainerCandidatePromotionRule.self,
            CityLabArticleContainerCandidateRule.self,
            SimonWillisonBeatCandidatePromotionRule.self
        ]
        for rule in rules {
            if let promoted = rule.promotedCandidate(from: candidate) {
                return promoted
            }
        }
        return nil
    }

    static func shouldKeepCandidate(_ current: Element) -> Bool {
        let rules: [CandidateProtectionSiteRule.Type] = [
            CityLabArticleContainerCandidateRule.self
        ]
        for rule in rules where rule.shouldKeepCandidate(current) {
            return true
        }
        return false
    }

    static func shouldKeepBylineContainer(
        _ node: Element,
        sourceURL: URL?,
        document: Document
    ) throws -> Bool {
        let rules: [BylineContainerRetentionSiteRule.Type] = [
            EHowAuthorProfileBylineRetentionRule.self,
            WebMDAuthorBylineRetentionRule.self
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
        try applyArticleCleanerRules(phase: .unwantedElements, to: articleContent, context: context)
    }

    static func applyArticleCleanerRules(
        phase: ArticleCleanerSiteRulePhase,
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        try applyArticleCleanerRules(articleCleanerRules(for: phase), to: articleContent, context: context)
    }

    private static func articleCleanerRules(for phase: ArticleCleanerSiteRulePhase) -> [ArticleCleanerSiteRule.Type] {
        switch phase {
        case .unwantedElements:
            return [
                AntirezDisqusFooterRule.self,
                AntirezLeadingInfoRule.self,
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
                BerthubNavigationChromeRule.self,
                EngadgetSlideshowIconRule.self,
                WikipediaLeadMetaNoiseRule.self,
                FirefoxNightlyCommentFormRule.self,
                SubstackDiscussionFooterRule.self,
                MozillaCustomizeSyncSectionRule.self,
                EHowAuthorProfileRule.self,
                SimplyFoundMediaContainerRule.self,
                FolhaGalleryWidgetRule.self,
                PixnetArticleKeywordRule.self,
                WebMDReviewedByRule.self
            ]
        case .preConversion:
            return [
                NYTimesRelatedLinkCardsRule.self
            ]
        case .shareCleanup:
            return [
                GuardianShareElementsRule.self
            ]
        case .postParagraph:
            return [
                NYTimesSplitPrintInfoRule.self
            ]
        case .postProcess:
            return [
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
                DFarqShareAuthorTailRule.self,
                SubstackTwitterEmbedRule.self,
                WordPressPrevNextNavigationRule.self,
                JohnDCookRelatedPostsRule.self,
                MercurialExampleSectionRule.self,
                SimonWillisonRecentArticlesRule.self,
                WikipediaHermitianListPruneRule.self,
                EbbPreviousLinkRule.self
            ]
        }
    }

    /// Returns the explicit sibling inclusion decision, if any site rule produced one.
    static func siblingInclusionDecision(
        _ sibling: Element,
        topCandidate: Element,
        inspectionContext: InspectionContext? = nil
    ) throws -> SiblingInclusionDecision? {
        let rules: [SiblingInclusionSiteRule.Type] = [
            WordPressFeaturedImageRule.self
        ]
        for rule in rules {
            if let decision = try rule.shouldIncludeSibling(sibling, topCandidate: topCandidate) {
                inspectionContext?.recordSiteRuleDecision(
                    phase: SiblingMergeSiteRulePhase.siblingInclude.rawValue,
                    ruleID: rule.id,
                    target: sibling,
                    action: decision ? "include" : "exclude",
                    reason: "explicit-decision"
                )
                return SiblingInclusionDecision(ruleID: rule.id, include: decision)
            }
        }
        return nil
    }

    /// Returns an extracted sub-element from the sibling if any site rule wants to extract one.
    /// When non-nil is returned, the caller should append the returned element and skip the original sibling.
    static func siblingExtraction(
        _ sibling: Element,
        topCandidate: Element,
        inspectionContext: InspectionContext? = nil
    ) throws -> SiblingExtractionResult? {
        let rules: [SiblingExtractSiteRule.Type] = [
            WordPressFeaturedImageExtractRule.self
        ]
        for rule in rules {
            if let extracted = try rule.extractFromSibling(sibling, topCandidate: topCandidate) {
                inspectionContext?.recordSiteRuleDecision(
                    phase: SiblingMergeSiteRulePhase.leadingAssociatedContent.rawValue,
                    ruleID: rule.id,
                    target: sibling,
                    action: "extract",
                    result: extracted,
                    reason: "sub-element-extracted"
                )
                return SiblingExtractionResult(ruleID: rule.id, element: extracted)
            }
        }
        return nil
    }

    static func applyPreConversionRules(
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        try applyArticleCleanerRules(phase: .preConversion, to: articleContent, context: context)
    }

    static func applyShareRules(
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        try applyArticleCleanerRules(phase: .shareCleanup, to: articleContent, context: context)
    }

    static func applyPostProcessRules(
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        try applyArticleCleanerRules(phase: .postProcess, to: articleContent, context: context)
    }

    static func applyPostParagraphRules(
        to articleContent: Element,
        context: ArticleCleanerSiteRuleContext
    ) throws {
        try applyArticleCleanerRules(phase: .postParagraph, to: articleContent, context: context)
    }
}

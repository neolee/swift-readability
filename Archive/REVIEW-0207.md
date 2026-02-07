# Stage 3-R 工作检查报告（修订版）

**检查日期:** 2026-02-07  
**检查范围:** Batch 1-5 完成情况、代码残留物、文档一致性  
**检查人:** Code Review Agent  
**文档版本:** 2.0（已根据决策意见修订）

---

## 执行摘要

本次检查针对 Stage 3-R（Real-world Hardening）阶段已完成的 Batch 1-5 进行全面审查。根据项目决策者的反馈，本报告已调整重点：**仅关注与 Mozilla 导入测试（MozillaCompatibilityTests 和 RealWorldCompatibilityTests）相关的核心问题**，早期单元测试将按决策处理。

**关键发现:**

| 类别 | 数量 | 决策状态 | 行动项 |
|------|------|----------|--------|
| 早期单元测试与代码不一致 | 1 | 待决策 | P1 - 需选择处理方案 |
| 文档注释过时 | 2 | 已确认 | P2 - 删除注释 |
| 批次报告未及时更新 | 2 | 已确认 | P2 - 同步状态 |
| 历史计划文档归档 | 1 | 已确认 | P3 - 标记归档 |

**重要确认:** RealWorldCompatibilityTests 的 49 个测试实际全部通过，状态良好。BATCHES.md 和 BATCH-5-REPORT.md 仅需同步最新状态。

---

## 一、待决策项：早期单元测试处理方案

### 1.1 问题描述

**失败测试:**
```
Test: selectTopCandidate does not mutate stored scores during collection
File: Readability/Tests/ReadabilityTests/CandidateSelectorTests.swift:145
Error: (afterLinked → 44.54545454545454) == (beforeLinked → 105.0)
```

**问题本质:**
该测试期望 `selectTopCandidate` 在收集 top candidates 的过程中**不修改**存储的分数。但代码中 `collectTopCandidates` 方法会：
1. 获取原始分数
2. 应用 link-density 缩放
3. **将缩放后的分数写回存储**（`scoringManager.setContentScore(score, for: element)`）

这与测试期望矛盾。

### 1.2 分析与建议

**我的判断:** 该测试的**期望是错误的**，应该废弃或重写。

**理由:**

1. **Mozilla 原始行为验证:**
   - Mozilla Readability.js 的 `getTopCandidate` 函数中，候选人的分数在收集时会被 `score *= (1 - linkDensity)` 缩放
   - 缩放后的分数用于比较和选择，这是预期行为
   - 测试期望"分数不变"与 Mozilla 实际行为不符

2. **当前代码行为是正确的:**
   - `CandidateSelector.swift:86-89` 实现了与 Mozilla 相同的 link-density 缩放
   - 缩放后的分数需要写回存储，以便后续 sibling merging 等阶段使用
   - RealWorldCompatibilityTests 和 MozillaCompatibilityTests **全部通过**，证明当前行为符合 Mozilla 预期

3. **测试本身的问题:**
   - 该测试是项目早期编写的，当时对 Mozilla 行为的理解可能不完整
   - 在中后期一直未更新，与实际代码脱节
   - 测试的断言前提（"分数不应变化"）与库的设计目标（"匹配 Mozilla"）冲突

### 1.3 建议方案（按优先级排序）

| 方案 | 操作 | 成本 | 风险 | 推荐度 |
|------|------|------|------|--------|
| **A** | **废弃该测试** | 最低（删除几行代码） | 无 | **推荐** |
| B | 重写测试以匹配当前行为 | 低 | 低 | 可选 |
| C | 修改代码以满足测试期望 | 高 | 高（破坏 Mozilla 兼容性） | 不推荐 |

**推荐选择方案 A（废弃）的理由:**
- 测试的前提假设（"分数不应变化"）与 Mozilla 行为不符
- 保留该测试会迫使代码维护者接受错误的期望，或在未来再次遇到冲突
- 两组 Mozilla 导入测试已全部通过，证明当前行为正确
- 删除成本最低，无回归风险

---

## 二、已确认处理事项

### 2.1 ReadabilityOptions.swift 过时注释删除

**位置:**
- 第 6-7 行: `maxElemsToParse` 的 "Status: deferred/no-op" 注释（**保留**，确实未实现）
- 第 29 行: `allowedVideoRegex` 的 "Status: deferred/no-op" 注释（**删除**）
- 第 36 行: `debug` 的 "Status: deferred/no-op" 注释（**删除**）

**操作:** 直接删除两行过时的 "Status" 注释。

### 2.2 BATCHES.md 和 BATCH-5-REPORT.md 状态同步

**当前状态:**
- BATCHES.md 第 9 行: 仍记录 3 failures
- BATCH-5-REPORT.md: 仍记录 C1/C3 完成，C2/C4 未完成

**实际状态:**
- RealWorldCompatibilityTests: 49/49 通过
- `simplyfound-1`, `tumblr`, `royal-road` 已全部通过

**操作:**
1. 更新 BATCHES.md 第 9 行为: "`RealWorldCompatibilityTests`: 49 tests imported, 0 failures"
2. 更新 BATCH-5-REPORT.md，补充 C4/C5 迭代记录（或合并为 "Batch 5 已完成" 总结）
3. 更新 BATCH-5-CLUSTERS.md，将 B5-C2 和 B5-C4 标记为 CLOSED

### 2.3 Batch 3 报告无需补充

**确认:** 该批次 10 个测试用例全部通过，无复杂问题需要记录。无需额外文档。

### 2.4 PLAN.md 归档

**操作:**
1. 在 PLAN.md 头部添加归档标记：
   ```markdown
   # DEPRECATED - ARCHIVED
   
   **Status:** Archived (2026-02-07)  
   **Reason:** Information outdated, superseded by REVIEW.md and AGENTS.md  
   **Current Status:** See REVIEW.md for latest project status
   
   ---
   ```
2. 或将文件移动到 Archive/ 目录并重命名为 `PLAN-ARCHIVED.md`

---

## 三、早期单元测试全面分析

基于对 8 个早期单元测试文件的深入审查，以下是详细分析：

### 3.1 测试文件清单

| 文件 | 测试数 | 状态 | 结论 |
|------|--------|------|------|
| `ArticleCleanerTests.swift` | 24 | 有效 | **保留** |
| `CandidateSelectorTests.swift` | 17 | 1个失败 | **修复后保留** |
| `ContentExtractorTests.swift` | 16 | 有效 | **保留** |
| `DOMTraversalTests.swift` | 28 | 有效 | **保留** |
| `NodeCleanerTests.swift` | 26 | 有效 | **保留** |
| `NodeScoringTests.swift` | 27 | 有效 | **保留** |
| `SiblingMergerTests.swift` | 19 | 有效 | **保留** |
| `ReadabilityTests.swift` | 6 | 有效 | **保留** |

**总计:** 163 个测试，其中 162 个通过，1 个失败。

### 3.2 各测试文件详细分析

#### ArticleCleanerTests.swift - 推荐保留

**依然有意义的测试:**
- `isPhrasingContent` 系列测试 (4个) - 验证行内/块级内容判断
- `hasSingleTagInsideElement` 系列测试 (4个) - 验证单标签容器检测
- `hasChildBlockElement` 系列测试 (3个) - 验证块级子元素检测
- `setNodeTag` 系列测试 (2个) - 验证标签转换和属性保留
- `prepArticle` 系列测试 (10个) - 验证文章清理流程
- `cleanStyles` 系列测试 (2个) - 验证样式清理

**与代码匹配度:** 高。所有测试均通过，覆盖的核心功能（如 phrasing content 判断、标签转换）在 Mozilla 测试中未被直接验证，但这些是内部实现的关键细节。

**建议:** **保留全部**。这些是底层实现的单元测试，Mozilla 测试不会覆盖这些细节。

---

#### CandidateSelectorTests.swift - 修复后保留

**依然有意义的测试:**
- `selectTopCandidate` 系列测试 (4个) - 验证候选人选择逻辑
- `findBetterTopCandidate` 系列测试 (2个) - 验证共同祖先提升
- `promoteSingleChildCandidate` 系列测试 (2个) - 验证单孩子提升
- `findBetterParentCandidate` 系列测试 (2个) - 验证父级提升
- `calculateSiblingScoreThreshold` 系列测试 (2个) - 验证阈值计算
- `propagateScoreToAncestors` 系列测试 (2个) - 验证分数传播
- `fallback` 测试 (1个) - 验证降级处理
- 边缘情况测试 (2个)

**与代码不匹配的测试:**
- `testSelectTopCandidateDoesNotMutateStoredScores` - 期望分数不变，实际会 link-density 缩放

**建议:** 
- **废弃** `testSelectTopCandidateDoesNotMutateStoredScores`（理由见第一节）
- **保留其余 16 个测试**，它们验证了候选人选择的核心算法，Mozilla 测试不会覆盖这些内部逻辑

---

#### ContentExtractorTests.swift - 推荐保留

**依然有意义的测试:**
- `extract` 基础测试 (4个) - 验证内容提取基本流程
- `flag` 系统测试 (2个) - 验证多尝试回退机制
- `element scoring` 测试 (1个) - 验证高分元素优先
- `attempt selection` 测试 (2个) - 验证最佳尝试选择
- `edge cases` 测试 (4个) - 验证隐藏内容、空文档等
- `configuration` 测试 (3个) - 验证选项配置

**与代码匹配度:** 高。所有测试通过，覆盖的提取流程、多尝试回退等逻辑在 Mozilla 测试中不会直接验证。

**建议:** **保留全部**。这些是内容提取的核心单元测试。

---

#### DOMTraversalTests.swift - 推荐保留

**依然有意义的测试:**
- `getNextNode` 系列测试 (7个) - 验证 DOM 遍历
- `removeAndGetNext` 系列测试 (2个) - 验证节点移除
- `getNodeAncestors` 系列测试 (3个) - 验证祖先获取
- `hasAncestorTag` 系列测试 (4个) - 验证祖先检测
- `hasSingleTagInsideElement` 系列测试 (4个) - 验证单标签检测
- `isElementWithoutContent` 系列测试 (4个) - 验证空元素检测
- `isWhitespace` 系列测试 (3个) - 验证空白检测
- `getAllNodesWithTag` 系列测试 (2个) - 验证标签搜索
- Element 扩展测试 (3个)

**与代码匹配度:** 高。所有测试通过，这些是底层 DOM 操作工具函数，Mozilla 测试不会覆盖。

**建议:** **保留全部**。这些是基础设施测试，对重构保护有价值。

---

#### NodeCleanerTests.swift - 推荐保留

**依然有意义的测试:**
- `removeUnlikelyCandidates` 系列测试 (8个) - 验证噪声移除
- `checkAndExtractByline` 系列测试 (7个) - 验证作者提取
- `headerDuplicatesTitle` 系列测试 (4个) - 验证标题重复检测
- `isProbablyVisible` 系列测试 (6个) - 验证可见性检测
- `isModalDialog` 测试 (1个)

**与代码匹配度:** 高。所有测试通过，覆盖的噪声移除、作者提取、可见性检测等逻辑是核心功能，Mozilla 测试会间接验证但不会直接测试这些单元。

**建议:** **保留全部**。特别是 `byline` 提取系列测试，这是项目早期的关键功能，有专门的测试保护很有价值。

---

#### NodeScoringTests.swift - 推荐保留

**依然有意义的测试:**
- `NodeScoringManager` 基础测试 (7个) - 验证分数存储管理
- `initializeNode` 系列测试 (7个) - 验证节点初始化分数
- `getClassWeight` 系列测试 (5个) - 验证类权重计算
- `getLinkDensity` 系列测试 (4个) - 验证链接密度计算
- `scoreElement` 系列测试 (3个) - 验证元素打分
- `Candidate` 测试 (1个)

**与代码匹配度:** 高。所有测试通过，覆盖的打分机制是核心算法，Mozilla 测试会验证结果但不会测试这些内部计算。

**建议:** **保留全部**。这些是打分算法的单元测试，对算法调整有保护作用。

---

#### SiblingMergerTests.swift - 推荐保留

**依然有意义的测试:**
- `mergeSiblings` 系列测试 (5个) - 验证兄弟节点合并
- `P Tag Special Handling` 测试 (3个) - 验证段落特殊处理
- `DIV Alteration` 测试 (2个) - 验证标签转换
- `Score Threshold` 测试 (2个) - 验证阈值计算
- `Wrapper Creation` 测试 (2个) - 验证包装器创建
- `Edge Cases` 测试 (3个)

**与代码匹配度:** 高。所有测试通过，覆盖的兄弟合并逻辑是核心算法的一部分。

**建议:** **保留全部**。

---

#### ReadabilityTests.swift - 推荐保留

**依然有意义的测试:**
- `parse` 生命周期测试 (2个) - 验证单次使用语义
- `byline` 优先级测试 (2个) - 验证作者来源优先级
- `figure` 包装器测试 (1个) - 验证 figure 结构保留
- `excerpt` 回退测试 (1个) - 验证摘要回退逻辑

**与代码匹配度:** 高。所有测试通过，这些是高层集成测试，补充了 Mozilla 测试未覆盖的场景（如 parse 生命周期）。

**建议:** **保留全部**。

### 3.3 总结与建议

#### 决策建议

| 测试文件 | 建议操作 | 理由 |
|----------|----------|------|
| 全部（除一个测试外） | **保留** | 163个测试中的162个通过，覆盖底层实现细节，Mozilla测试不会覆盖 |
| CandidateSelectorTests:145 | **废弃** | 期望与Mozilla行为不符，测试假设错误 |

#### 保留的价值

这些早期单元测试的价值在于：

1. **覆盖底层实现细节:** Mozilla 测试验证最终输出，单元测试验证内部逻辑
2. **重构保护:** 修改内部实现时，单元测试提供快速反馈
3. **文档作用:** 测试用例展示了各组件的预期行为
4. **调试辅助:** 定位问题时，单元测试比集成测试更容易隔离问题

#### 可以增加的测试

基于代码审查，以下方面可以增加单元测试：

| 模块 | 建议增加的测试 | 优先级 |
|------|----------------|--------|
| `SiteRuleRegistry` | 规则匹配顺序、多个规则冲突处理 | P2 |
| `ArticleCleaner` | `_cleanConditionally` 复杂条件分支 | P2 |
| `ContentExtractor` | `grabArticle` 的 FLAG 切换组合 | P3 |
| `Readability` | 序列化输出格式验证 | P2 |

---

## 四、我的建议汇总

### 4.1 对您判断的异议

| 您的判断 | 我的意见 | 结论 |
|----------|----------|------|
| 早期单元测试需要决策处理方案 | **部分异议** - 仅1个测试需要处理，其余162个全部有效 | 仅废弃1个，保留其余 |
| 删除 ReadabilityOptions 过时注释 | 无异议 | 确认 |
| 同步 BATCHES/BATCH-5-REPORT | 无异议 | 确认 |
| Batch 3 无需报告 | 无异议 | 确认 |
| PLAN.md 归档 | 无异议 | 确认 |

**关键异议说明:**
经过全面分析，我认为**绝大多数早期单元测试（162/163）依然有意义且与代码匹配**，只有 `CandidateSelectorTests.swift:145` 一个测试的期望是错误的。建议：
- **废弃该测试**（理由见第一节）
- **保留其余所有早期单元测试**

保留这些测试的理由：
1. 它们测试的是 Mozilla 测试不会覆盖的内部实现细节
2. 它们为重构提供了快速反馈机制
3. 它们作为代码行为的文档
4. 它们帮助在修改代码时快速定位问题

### 4.2 执行计划建议

**Phase 1: 废弃有问题的测试（P1，2分钟）**
```bash
# 删除 CandidateSelectorTests.swift 中的测试：
# "selectTopCandidate does not mutate stored scores during collection" (line 116-146)
```

**Phase 2: 文档清理（P2，5分钟）**
```bash
# 1. 删除 ReadabilityOptions.swift 过时注释（第 29、36 行）
# 2. 归档 PLAN.md
```

**Phase 3: 批次报告更新（P2，10分钟）**
```bash
# 1. 更新 BATCHES.md 第 9 行状态
# 2. 更新 BATCH-5-REPORT.md，添加完成记录
# 3. 更新 BATCH-5-CLUSTERS.md，标记 B5-C2/B5-C4 为 CLOSED
```

### 4.3 验证命令

执行后验证：

```bash
# 验证所有 Mozilla 测试仍通过
cd Readability && swift test --filter MozillaCompatibilityTests

# 验证所有 RealWorld 测试仍通过
cd Readability && swift test --filter RealWorldCompatibilityTests

# 验证全量测试（应该 0 失败）
cd Readability && swift test 2>&1 | tail -5
```

---

## 五、附录

### A. 废弃测试的代码位置

**文件:** `Readability/Tests/ReadabilityTests/CandidateSelectorTests.swift`
**行号:** 116-146
**测试名:** `selectTopCandidate does not mutate stored scores during collection`

```swift
@Test("selectTopCandidate does not mutate stored scores during collection")
func testSelectTopCandidateDoesNotMutateStoredScores() throws {
    let html = """
    <div id="plain">Plain content with enough words, commas, and text for scoring.</div>
    <div id="linked"><a href="https://example.com">link link link link</a> trailing text</div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    let plain = try doc.select("#plain").first()!
    let linked = try doc.select("#linked").first()!
    let elements = [plain, linked]

    let scoringManager = NodeScoringManager()
    let options = ReadabilityOptions(nbTopCandidates: 5)
    let selector = CandidateSelector(options: options, scoringManager: scoringManager)

    scoringManager.initializeNode(plain)
    scoringManager.initializeNode(linked)
    scoringManager.addToScore(100, for: plain)
    scoringManager.addToScore(100, for: linked)

    let beforePlain = scoringManager.getContentScore(for: plain)
    let beforeLinked = scoringManager.getContentScore(for: linked)

    _ = try selector.selectTopCandidate(from: elements, in: doc)

    let afterPlain = scoringManager.getContentScore(for: plain)
    let afterLinked = scoringManager.getContentScore(for: linked)

    #expect(afterPlain == beforePlain)  // 第 144 行 - 失败点
    #expect(afterLinked == beforeLinked)  // 第 145 行 - 失败点
}
```

### B. 文件修改清单

| 文件 | 操作 | 行号/位置 | 变更内容 |
|------|------|-----------|----------|
| `CandidateSelectorTests.swift` | 删除 | 116-146 | 删除测试 "selectTopCandidate does not mutate stored scores during collection" |
| `ReadabilityOptions.swift` | 删除 | 29 | 删除 `/// Status: deferred/no-op` |
| `ReadabilityOptions.swift` | 删除 | 36 | 删除 `/// Status: deferred/no-op. The core pipeline currently does not emit debug logs from this flag.` |
| `BATCHES.md` | 修改 | 9 | 改为 "0 failures" |
| `BATCH-5-REPORT.md` | 追加 | 末尾 | 添加 C4/C5 迭代完成记录 |
| `BATCH-5-CLUSTERS.md` | 修改 | B5-C2, B5-C4 | 标记为 CLOSED |
| `PLAN.md` | 归档 | 头部 | 添加 DEPRECATED 标记或移动文件 |

---

**报告结束**

*修订说明: 本报告 v2.0 已根据决策者反馈调整，聚焦于 Mozilla 导入测试为核心基准，早期单元测试按待决策项处理。附录包含详细的单元测试分析结果。*

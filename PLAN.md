# Swift Readability 移植实施计划

本文档规划 Mozilla Readability.js 到 Swift 的分步移植方案，确保每一步都有可验证的结果。

## 项目背景

- **源代码**: Mozilla Readability.js (~2,500 行)
- **目标**: 纯 Swift 实现，使用 SwiftSoup，无 WKWebView
- **测试基准**: Mozilla 官方测试套件 (50+ 个真实网页用例)
- **当前状态**: MVP 阶段，基础评分算法已实现

## 移植策略

采用**渐进增强**策略：
1. 从核心算法开始，逐步添加功能
2. 每阶段都有明确的验证标准
3. 保持代码可运行和测试通过
4. 优先移植高频使用功能，边缘情况后续处理

---

## Phase 1: 基础架构完善 ✅ 已完成

**目标**: 建立完整的项目结构和配置系统

**状态**: 已完成 (9 项测试通过)

### 1.1 配置系统 (`ReadabilityOptions`) ✅

**已完成**:
```swift
public struct ReadabilityOptions: Sendable {
    var maxElemsToParse: Int      // 默认 0 (无限制)
    var nbTopCandidates: Int      // 默认 5
    var charThreshold: Int        // 默认 500
    var keepClasses: Bool         // 默认 false
    var disableJSONLD: Bool       // 默认 false
    var classesToPreserve: [String]
    var allowedVideoRegex: String
    var linkDensityModifier: Double
    var debug: Bool
}
```

**验证结果**:
- ✅ 配置项可以被正确传递
- ✅ 默认配置能正确处理标准网页
- [ ] CLI 支持 `--config` 参数 (Phase 6)

### 1.2 错误类型体系 ✅

**已完成**:
```swift
public enum ReadabilityError: Error, CustomStringConvertible, Sendable {
    case noContent
    case contentTooShort(actualLength: Int, threshold: Int)
    case parsingFailed(underlying: Error)
    case invalidHTML
    case elementNotFound(String)
}
```

**验证结果**:
- ✅ 每种错误都能被正确抛出和捕获
- ✅ 错误信息清晰有用
- ✅ CLI 能正确显示错误信息

### 1.3 目录结构调整 ✅

**已完成结构**:
```
Sources/Readability/
├── Readability.swift              # 主入口
├── ReadabilityOptions.swift       # 配置选项 ✅
├── ReadabilityResult.swift        # 结果结构
├── ReadabilityError.swift         # 错误定义 ✅
└── Internal/
    ├── Configuration.swift        # 常量配置 ✅
    └── DOMHelpers.swift           # DOM 工具方法 ✅
```

**待后续 Phase 补充**:
- DocumentPreparer.swift
- ArticleGrabber.swift
- ContentScorer.swift
- ContentCleaner.swift
- MetadataExtractor.swift

**验证结果**:
- ✅ 项目能正常编译
- ✅ 所有原有功能正常工作
- ✅ 内部模块间无循环依赖

---

## Phase 2: 文档预处理完善 (Day 2-3)

**目标**: 完整实现 `prepDocument` 和相关方法

### 2.1 完整标签移除

当前实现: `script, style, noscript, iframe, object, embed`

需补充:
- `template` - 模板标签
- `svg` 内容处理 (可选但保留引用)

**验证标准**:
```swift
@Test func testScriptRemoval() async throws {
    let html = "<html><script>alert('x')</script><body><p>Content</p></body></html>"
    let result = try Readability(html: html).parse()
    #expect(!result.content.contains("script"))
    #expect(!result.content.contains("alert"))
}
```

### 2.2 BR 标签替换 (`replaceBrs`)

当前实现: 基础版本

完善内容:
- 处理连续多个 BR 标签
- 转换为段落标签
- 保留文本内容

**验证标准**:
```swift
@Test func testBrsToParagraphs() async throws {
    let html = "<p>Line1<br><br>Line2</p>"
    let result = try Readability(html: html).parse()
    #expect(result.content.contains("<p>Line1</p>"))
}
```

### 2.3 字体标签转换

将 `<font>` 标签转换为 `<span>` 标签，保留样式

**验证标准**:
- `<font color="red">Text</font>` → `<span>Text</span>`
- 内容被保留，标签被替换

---

## Phase 3: 元数据提取完善 (Day 3-4)

**目标**: 完整的标题、作者、站点名、发布时间提取

### 3.1 JSON-LD 解析

实现 JSON-LD (`application/ld+json`) 解析：

```swift
// 提取 @type = NewsArticle, Article 等的信息
// 字段: headline, author, datePublished, publisher 等
```

**验证标准**:
```swift
@Test func testJSONLDExtraction() async throws {
    let html = """
    <script type="application/ld+json">
    {
        "@type": "NewsArticle",
        "headline": "Article Title",
        "author": {"name": "John Doe"},
        "datePublished": "2024-01-01"
    }
    </script>
    """
    let result = try Readability(html: html).parse()
    #expect(result.title == "Article Title")
    #expect(result.byline == "John Doe")
}
```

### 3.2 Open Graph 标签

提取 `og:title`, `og:description`, `og:site_name`

### 3.3 Dublin Core 和 Twitter Cards

- `dc:title`, `dc:creator`
- `twitter:title`, `twitter:description`

### 3.4 智能标题清理

当前实现: 基础版本

完善:
- 更多分隔符处理
- 站点名识别和移除
- 标题层级匹配 (h1 vs title 标签)

**验证标准**:
```swift
// 输入: <title>Article Title - Site Name</title>
// 输出: "Article Title" (移除站点名)
@Test func testTitleCleaning() async throws {
    let html = "<html><head><title>Great Article - My Blog</title></head><body><h1>Great Article</h1><p>Content</p></body></html>"
    let result = try Readability(html: html).parse()
    #expect(result.title == "Great Article")
}
```

---

## Phase 4: 核心评分算法增强 (Day 4-6)

**目标**: 完整的 `_grabArticle` 和 `_initializeNode` 逻辑

### 4.1 节点评分细化

当前实现: 基础版本

完善:
- 更细致的标签权重
- 属性评分 (class/id 匹配)
- 链接密度计算优化
- 祖先节点分数传播

```swift
// 参考 Mozilla 实现:
// - DIV/ARTICLE/SECTION: +5
// - PRE/TD/BLOCKQUOTE: +3
// - 其他容器: 根据内容动态计算
// - 文本长度: +1 per 100 chars (max 3)
// - 逗号数量: +1 per comma
// - class/id 匹配 positive patterns: +25
// - class/id 匹配 negative patterns: -25
// - 链接密度惩罚: score *= (1 - linkDensity)
```

**验证标准**:
- 能正确识别主要内容区
- 对常见布局 (文章+侧边栏) 正确处理
- 测试用例通过率 > 60%

### 4.2 候选节点选择优化

当前实现: 简单最高分选择

完善:
- Top N 候选收集
- 兄弟节点合并
- 向上查找共同祖先

**验证标准**:
```swift
@Test func testCandidateSelection() async throws {
    // 模拟文章页面结构
    let html = loadTestHTML("article-with-sidebar")
    let result = try Readability(html: html).parse()
    #expect(result.textContent.contains("Article content"))
    #expect(!result.textContent.contains("Sidebar content"))
}
```

### 4.3 多轮尝试机制

当内容过短或为空时，使用不同策略重试：

```swift
for attempt in 0..<maxAttempts {
    let result = try grabArticle(attempt: attempt)
    if isAcceptable(result) { return result }
}
```

**验证标准**:
- 第一遍失败时能尝试替代选择器
- 不会无限循环

---

## Phase 5: 内容清理完善 (Day 6-8)

**目标**: 完整的 `_prepArticle` 和 `_cleanConditionally`

### 5.1 条件清理 (`_cleanConditionally`)

根据内容特征决定是否移除元素：

移除条件:
- 图片/段落比例过高
- 输入框过多
- 链接密度过高 (> 0.2-0.5)
- 内容过短
- 看起来像广告/导航

**验证标准**:
```swift
@Test func testConditionalCleaning() async throws {
    let html = """
    <div>
        <p>Real article content here</p>
        <div class="comments">
            <p>Comment 1</p>
            <p>Comment 2</p>
        </div>
    </div>
    """
    let result = try Readability(html: html).parse()
    #expect(result.textContent.contains("Real article content"))
    #expect(!result.textContent.contains("Comment"))
}
```

### 5.2 标签清理和转换

- 移除不需要的属性 (style, class, id, onclick 等)
- 将 DIV 转换为 P (当内容适合时)
- 清理空的容器

### 5.3 图片处理

- 修复懒加载图片 (data-src → src)
- 移除小图片/图标
- 保留有意义的图片

**验证标准**:
```swift
@Test func testLazyImageFix() async throws {
    let html = """
    <img data-src="real.jpg" src="placeholder.gif">
    """
    let result = try Readability(html: html).parse()
    #expect(result.content.contains("real.jpg"))
}
```

---

## Phase 6: 高级功能 (Day 8-10)

### 6.1 分页处理

检测并处理多页文章:
- 查找 "下一页" 链接
- 合并分页内容

### 6.2 代码块保护

保护 `<pre>`, `<code>` 中的内容不被误清理

**验证标准**:
```swift
@Test func testCodeBlockPreservation() async throws {
    let html = "<pre><code>console.log('test');</code></pre>"
    let result = try Readability(html: html).parse()
    #expect(result.textContent.contains("console.log"))
}
```

### 6.3 表格处理

保留有意义的表格，移除布局表格

---

## Phase 7: 测试与基准 (持续进行)

### 7.1 导入 Mozilla 测试套件 ✅ 部分完成

**已完成**:
```
Tests/ReadabilityTests/Resources/
└── test-pages/
    ├── 001/                    # 真实文章测试
    ├── basic-tags-cleaning/    # 基础标签清理
    ├── remove-script-tags/     # 脚本移除
    └── replace-brs/            # BR 标签处理
```

**测试加载器**: `TestLoader.swift` 支持动态加载测试用例

**当前测试**: 9 项测试全部通过

### 7.2 测试覆盖率目标

| 阶段 | 目标通过率 | 说明 |
|------|-----------|------|
| Phase 2 结束 | 30% | 基础功能 |
| Phase 4 结束 | 60% | 核心算法 |
| Phase 5 结束 | 80% | 完整清理 |
| Phase 6 结束 | 90%+ | 高级功能 |

### 7.3 性能基准

- 大文档 (> 1MB HTML) 处理时间 < 1s
- 内存占用 < 50MB

---

## 开发检查清单

每个 Phase 完成前检查:

- [ ] 代码编译无警告
- [ ] 所有现有测试通过
- [ ] 新增功能有对应测试
- [ ] CLI 能正确处理测试 URL
- [ ] 文档已更新 (如需要)

---

## 快速验证命令

```bash
# 完整验证
cd Readability && swift build && swift test

# CLI 测试
cd ReadabilityCLI
swift run ReadabilityCLI https://soulhacker.me/posts/why-type-system-matters/ --text-only

# 本地 HTML 测试
cat test.html | swift run ReadabilityCLI --text-only
```

---

## 参考资源

1. **Mozilla Readability 源码**: https://github.com/mozilla/readability
2. **测试套件**: https://github.com/mozilla/readability/tree/main/test
3. **SwiftSoup 文档**: https://github.com/scinfu/SwiftSoup
4. **原始 JS 算法分析**: 见 INIT.md 第 2-3 节

---

## 下一步行动

### Phase 1 已完成 ✅
- 9 项测试全部通过
- 配置系统、错误体系、目录结构已就位
- Mozilla 测试套件框架已建立

### 立即开始: Phase 2 (文档预处理完善)
1. **导入更多 Mozilla 测试用例** - 选择 5-10 个覆盖不同场景
2. **完善 `prepDocument()`** - 处理 template 标签、特殊字符
3. **增强 `replaceBrs()`** - 优化段落分割逻辑
4. **添加更多预处理测试** - 验证清理逻辑

### 本周目标
- 完成 Phase 2 所有任务
- 测试用例达到 15-20 个
- 通过率保持 100%

### 里程碑
- Phase 2 结束: 30% Mozilla 测试通过率
- Phase 4 结束: 60% Mozilla 测试通过率
- Phase 5 结束: 80% Mozilla 测试通过率

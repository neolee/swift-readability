# Swift Readability 移植项目规划

## 1. 项目背景与动机

### 1.1 现有方案的问题

在某些 SwiftUI 项目中需要类似 Mozilla Readability 的算法实现，但现存的类似 `swift-readability` 的库（https://github.com/Ryu0118/swift-readability）存在**并发架构不兼容**问题：

- **强制 `@MainActor`**：整个库标记为 `@MainActor`，必须使用主线程执行
- **使用 `withCheckedThrowingContinuation`**：等待 `WKWebView` 的 JavaScript 回调，不响应 `Task` 取消
- **无法超时**：当 `readability.parse()` 卡住时（如 JavaScript 死锁），外部设置的超时机制无法强制终止
- **结构化并发死锁**：Swift 的 `withThrowingTaskGroup` 要求等待所有子任务完成，死锁任务导致整个 `TaskGroup` 永远挂起

### 1.2 技术验证

通过源码分析确认：

```swift
// ReadabilityRunner.parseHTML 核心逻辑
return try await withCheckedThrowingContinuation { [weak self] continuation in
    self?.messageHandler?.subscribeEvent { event in
        switch event {
        case let .contentParsed(readabilityResult):
            continuation.resume(returning: readabilityResult)  // ← 唯一解锁点
        // ... 其他情况
        }
    }
}
```

`WKWebView` 的 JavaScript 执行无法强制中断，导致 continuation 永远不会被 resume。

### 1.3 解决方案

**基于 SwiftSoup 纯 Swift 实现 Mozilla Readability 算法**，完全移除 `WKWebView` 依赖。

---

## 2. Mozilla Readability.js 源码分析

### 2.1 代码规模

| 指标 | 数值 |
|------|------|
| 总代码行数 | ~2,500 行（含注释） |
| 核心方法数 | ~40 个私有方法 + 1 个主入口 |
| 正则表达式 | 20+ 个复杂模式 |
| 配置常量 | 30+ 个（标签列表、分数权重等） |

### 2.2 核心算法流程

```
HTML String
    ↓
_prepDocument()          // 预处理：移除 script/style，替换 BR 标签
    ↓
_unwrapNoscriptImages()  // 处理懒加载图片
    ↓
_getArticleMetadata()    // 提取 meta 标签、JSON-LD 元数据
    ↓
_grabArticle()           // 【核心】候选容器评分与选择
    ↓
_prepArticle()           // 后处理：清理样式、标签转换
    ↓
_postProcessContent()    // URL 规范化、简化嵌套元素
    ↓
ReadabilityResult
```

### 2.3 关键算法详解

#### 2.3.1 候选容器评分（Content Scoring）

评分因素：
- 基础分：DIV +5, PRE/TD/BLOCKQUOTE +3, 列表/表单 -3, 标题 -5
- 文本长度：每 100 字符 +1 分（上限 3 分）
- 逗号数量：每个逗号 +1 分（文本密度的代理指标）
- class/id 权重：匹配 positive 模式 +25，匹配 negative 模式 -25
- 链接密度惩罚：`score * (1 - linkDensity)`
- 祖先节点衰减：父节点 1x，祖父节点 0.5x，曾祖父及以上 1/(level*3)x

#### 2.3.2 候选节点选择

1. 遍历所有段落/容器节点
2. 为每个节点及其祖先初始化 readability 分数
3. 选出分数最高的 top 5 候选
4. 如果最佳候选竞争激烈（分数接近），向上查找共同祖先
5. 合并兄弟节点（接近最佳候选分数的相邻容器）

#### 2.3.3 清理规则（`_cleanConditionally`）

移除条件（满足任一即移除）：
- 图片/段落比例过高（`img > 1` 且 `p/img < 0.5`）
- 列表项过多（`li > p`）
- 输入框过多（`input > p/3`）
- 链接密度过高（`> 0.2-0.5`，取决于权重）
- 内容过短且结构可疑
- 包含广告/加载提示文字

#### 2.3.4 元数据提取

优先级（从高到低）：
1. JSON-LD (`application/ld+json`)
2. Open Graph (`og:title`, `og:description`)
3. Dublin Core (`dc:title`, `dc:creator`)
4. Twitter Cards (`twitter:title`)
5. HTML `<title>` 标签（智能分割处理）

---

## 3. SwiftSoup 兼容性分析

### 3.1 完全支持的特性 ✅

| Readability.js API | SwiftSoup 等价方法 |
|-------------------|-------------------|
| `getElementsByTagName` | `getElementsByTag(_:)` |
| `querySelectorAll` | `select(_:)` (CSS 选择器) |
| `getAttribute` | `attr(_:)` |
| `setAttribute` | `attr(_:_:)` |
| `textContent` | `text()` |
| `innerHTML` | `html()` |
| `removeChild` | `remove()` |
| `appendChild` | `appendChild(_:)` |
| `parentNode` | `parent()` |
| `nextElementSibling` | `nextElementSibling()` |
| `firstElementChild` | `firstElement()` |
| `children` | `children()` |
| `className` | `className()` / `addClass(_:)` |
| `id` | `id()` |

### 3.2 需要适配的 ⚠️

#### 节点标签替换

JavaScript：
```javascript
// 直接修改 tagName
node.localName = tag.toLowerCase();
node.tagName = tag.toUpperCase();
```

Swift 方案：
```swift
// SwiftSoup 不支持直接修改标签名，需要重建节点
let replacement = Element(Tag(tag.lowercased()), baseUri)
for child in node.children() {
    try? replacement.appendChild(child)
}
try? node.replaceWith(replacement)
```

#### 文档片段操作

JavaScript：
```javascript
var fragment = doc.createDocumentFragment();
fragment.appendChild(node);
```

Swift 方案：
```swift
// 使用临时 Element 作为容器
let fragment = Element(Tag("div"), baseUri)
try? fragment.appendChild(node)
// 最后取 children 使用
```

### 3.3 HTML 序列化

SwiftSoup 支持：
- `element.outerHtml()` - 包含当前标签的完整 HTML
- `element.html()` - 仅内部 HTML
- 所有属性都会被正确序列化

---

## 4. 移植工作量评估

### 4.1 难度分级

| 模块 | 难度 | 预计时间 | 说明 |
|------|------|---------|------|
| 配置常量与正则 | 🟢 低 | 2h | 直接翻译 `REGEXPS` 和其他常量 |
| DOM 工具方法 | 🟢 低 | 3h | `_removeNodes`, `_getInnerText` 等 |
| 文档预处理 | 🟡 中 | 4h | `_prepDocument`, `_replaceBrs` |
| 元数据提取 | 🟡 中 | 4h | JSON-LD 解析、meta 标签处理 |
| 核心评分算法 | 🟡 中 | 6h | `_grabArticle`, `_initializeNode` |
| 文章后处理 | 🟡 中 | 4h | `_prepArticle`, 各种清理方法 |
| 测试与调优 | 🔴 高 | 1-2d | 多网站测试，参数微调 |

### 4.2 总计估算

- **MVP 版本**：1-2 天（核心评分 + 基础清理）
- **完整移植**：3-5 天（所有功能 + 测试）

---

## 5. 实现策略

### 5.1 推荐方案：分阶段实现

#### 阶段 1：MVP（1-2 天）

目标：能处理 80% 常见网站

必需实现：
- [ ] 基础配置常量（分数权重、标签列表）
- [ ] `_prepDocument()` - 预处理文档
- [ ] `_grabArticle()` 核心逻辑（简化版）
- [ ] 基础评分算法（class/id 权重 + 文本长度）
- [ ] 简单的元数据提取（title, meta description）
- [ ] 基础清理（移除 script/style）

暂不实现：
- 复杂的 `_cleanConditionally` 完整逻辑
- `_fixLazyImages` 懒加载修复
- 分页处理（`isPaging` 逻辑）
- 多轮尝试（`_attempts` 回退机制）

#### 阶段 2：完整功能（+2-3 天）

- [ ] JSON-LD 元数据提取
- [ ] `_cleanConditionally` 完整实现
- [ ] 图片懒加载修复
- [ ] 多轮回退机制（处理内容过短的情况）
- [ ] 完整的调试日志支持

### 5.2 接口设计

保持与现有 `swift-readability` 兼容，便于替换：

```swift
public struct ReadabilityResult {
    public let title: String
    public let byline: String?
    public let dir: String?           // text direction (ltr/rtl)
    public let lang: String?          // language code
    public let content: String        // cleaned HTML
    public let textContent: String    // plain text
    public let length: Int            // text length
    public let excerpt: String?       // first paragraph
    public let siteName: String?
    public let publishedTime: String?
}

public struct Readability {
    public init(options: ReadabilityOptions? = nil)
    
    public func parse(html: String, baseURL: URL?) async throws -> ReadabilityResult
    public func parse(url: URL) async throws -> ReadabilityResult
}

public struct ReadabilityOptions {
    public var maxElemsToParse: Int = 0  // 0 = no limit
    public var nbTopCandidates: Int = 5
    public var charThreshold: Int = 500
    public var keepClasses: Bool = false
    public var disableJSONLD: Bool = false
}
```

### 5.3 关键设计决策

1. **异步设计**：虽然 SwiftSoup 是同步的，但 parse 方法标记为 `async`，允许后续优化（如大文档分段处理）

2. **错误处理**：
   - `ReadabilityError.noContent` - 无法找到文章内容
   - `ReadabilityError.contentTooShort` - 提取内容低于阈值
   - 其他错误作为 `ReadabilityError.parsingFailed` 包装

3. **可配置性**：支持通过 options 调整所有阈值和开关

4. **调试支持**：内部使用 `Logger`，可通过选项启用详细日志

---

## 6. 测试策略

### 6.1 测试用例来源

Mozilla Readability 官方测试套件：https://github.com/mozilla/readability/tree/main/test

包含：
- 50+ 个真实网页测试用例
- 预期输出（expected output）
- 覆盖新闻、博客、论坛等多种场景

### 6.2 测试方法

```swift
func testWebPage() async throws {
    let html = loadTestResource("test-case")
    let result = try await Readability().parse(html: html, baseURL: nil)
    
    XCTAssertEqual(result.title, "Expected Title")
    XCTAssertTrue(result.textContent.contains("Expected content"))
    XCTAssertGreaterThan(result.length, 500)
}
```

---

## 7. 项目结构建议

```
Sources/
├── Readability/
│   ├── Readability.swift           # 主入口，公共 API
│   ├── ReadabilityOptions.swift    # 配置选项
│   ├── ReadabilityResult.swift     # 结果结构体
│   ├── Internal/
│   │   ├── DocumentPreparer.swift  # _prepDocument 逻辑
│   │   ├── ArticleGrabber.swift    # _grabArticle 核心
│   │   ├── ContentScorer.swift     # 评分算法
│   │   ├── MetadataExtractor.swift # 元数据提取
│   │   ├── ContentCleaner.swift    # _prepArticle, 清理逻辑
│   │   ├── RegexPatterns.swift     # 所有正则表达式
│   │   ├── Configuration.swift     # 常量配置
│   │   └── DOMHelpers.swift        # DOM 工具方法
Tests/
├── ReadabilityTests/
│   ├── ReadabilityTests.swift
│   └── Resources/
│       └── test-pages/             # Mozilla 官方测试用例
```

---

## 8. 风险与缓解

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|---------|
| SwiftSoup DOM 操作差异导致行为不一致 | 中 | 高 | 使用 Mozilla 官方测试套件全面测试 |
| 某些网站依赖 JS 渲染后内容 | 高 | 中 | 明确文档说明限制，提供 fallback 策略 |
| 性能问题（大文档处理慢） | 低 | 中 | 使用 Instruments 分析，必要时添加流式处理 |
| 特定网站格式适配问题 | 中 | 低 | 收集真实用例，持续迭代优化 |

---

## 9. 参考资料

1. **Mozilla Readability 源码**：https://github.com/mozilla/readability
2. **SwiftSoup 文档**：https://github.com/scinfu/SwiftSoup
3. **Python Readability 移植**（参考实现）：https://github.com/buriy/python-readability
4. **Go Readability 移植**：https://github.com/go-shiori/go-readability

---

## 10. 下一步行动

1. [ ] 创建项目仓库，设置 Package.swift
2. [ ] 实现阶段 1 MVP（核心评分算法）
3. [ ] 导入 Mozilla 测试用例，建立基准
4. [ ] 集成到主项目验证可行性
5. [ ] 根据反馈完善阶段 2 功能

---

## 11. 文档后续加强（待实现后补充）

以下项目建议在实际开发完成后补充到本文档：

### 11.1 实施记录
- 移植过程中遇到的实际技术问题和解决方案
- SwiftSoup 与 JavaScript DOM API 的具体差异及适配方案
- 正则表达式性能优化经验

### 11.2 性能基准
- 大文档处理时间 vs WKWebView 方案对比
- 内存占用数据
- CPU 使用率分析（Instruments 结果）

### 11.3 兼容性矩阵
- Mozilla 官方测试套件通过情况（如 47/52 个测试通过）
- 针对特定网站的适配状态

### 11.4 已知限制
- 无法处理的边界情况（重度 JS 渲染页面、非标准 HTML 等）
- 与原版 Readability.js 的行为差异说明

### 11.5 文档语言更新
- 第 4-5 节的规划语气（"预计""建议"）改为实施后的现状描述
- 第 8 节风险表添加"已验证/已缓解"状态标注

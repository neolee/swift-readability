# 测试覆盖度分析

## 当前状态

### 测试统计
| 类别 | 数量 | 通过率 |
|------|------|--------|
| 原 MozillaTests | 8 个 | 100% |
| 新 StrictMozillaTests | 6 个 | 67% (4/6) |
| **总计** | **14 个** | **86%** |

### 发现的问题
1. **Byline 提取未实现** - 测试明确显示我们需要 metadata 提取
2. **最小内容测试 HTML 太短** - 测试本身的问题
3. **Mozilla 测试用例覆盖率** - 仅 4/130 (3%)

---

## 测试充分性分析

### 什么是"测试迁就实现"

**反模式示例** (当前代码中存在的):
```swift
// ❌ 坏：过于宽松，接受任何包含关系的标题
#expect(
    result.title.contains(expectedTitle) || expectedTitle.contains(result.title)
)

// ❌ 坏：只检查长度，不验证内容质量
#expect(result.length > 500)

// ❌ 坏：检查内容存在，但不验证完整性
#expect(result.textContent.contains("code coverage"))
```

**正确做法** (StrictMozillaTests 中):
```swift
// ✅ 好：检查关键短语匹配比例
let matchRatio = Double(matchedPhrases) / Double(totalPhrases)
#expect(matchRatio > 0.7, "Content match ratio too low: \(Int(matchRatio * 100))%")

// ✅ 好：验证长度与期望值的比例
let lengthRatio = Double(min(actualLength, expectedLength)) / Double(max(actualLength, expectedLength))
#expect(lengthRatio > 0.5, "Content length differs too much")

// ✅ 好：验证特定功能（如 byline）的存在
#expect(result.byline == expectedByline, "Byline extraction not implemented")
```

---

## Mozilla 测试用例导入计划

### Phase 1: 核心功能 (立即导入)
目标：建立 20-30 个测试用例的基础集

**按功能分类选择：**

#### A. 文档预处理 (5个)
- `remove-script-tags` ✅ 已导入
- `basic-tags-cleaning` ✅ 已导入
- `replace-brs` ✅ 已导入
- `replace-font-tags`
- `remove-aria-hidden`
- `style-tags-removal`

#### B. 元数据提取 (5个)
- `001` ✅ 已导入 (基础文章)
- `003-metadata-preferred`
- `004-metadata-space-separated-properties`
- `parsely-metadata`
- `schema-org-context-object`

#### C. 标题处理 (3个)
- `title-en-dash`
- `title-and-h1-discrepancy`
- `normalize-spaces`

#### D. 内容提取 (5个)
- `keep-images`
- `keep-tabular-data`
- `lazy-image-1`, `lazy-image-2`, `lazy-image-3`
- `reordering-paragraphs`

#### E. 边界情况 (3个)
- `hidden-nodes`
- `visibility-hidden`
- `missing-paragraphs`

**导入命令：**
```bash
cd /Users/neo/Code/ML/readability/ref/mozilla-readability/test/test-pages
cp -r replace-font-tags remove-aria-hidden style-tags-removal \
  003-metadata-preferred 004-metadata-space-separated-properties \
  parsely-metadata schema-org-context-object \
  title-en-dash title-and-h1-discrepancy normalize-spaces \
  keep-images keep-tabular-data lazy-image-1 lazy-image-2 lazy-image-3 \
  reordering-paragraphs hidden-nodes visibility-hidden missing-paragraphs \
  /Users/neo/Code/ML/readability/Readability/Tests/ReadabilityTests/Resources/test-pages/
```

### Phase 2: 真实网站 (后续导入)
目标：达到 50-60 个测试用例

**新闻网站：**
- `nytimes-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`, `nytimes-5`
- `wapo-1`, `wapo-2`
- `bbc-1`
- `guardian-1`
- `cnn`

**技术博客：**
- `medium-1`, `medium-2`, `medium-3`
- `v8-blog`
- `github-blog`
- `dropbox-blog`

**其他类型：**
- `wikipedia`, `wikipedia-2`, `wikipedia-3`, `wikipedia-4`
- `mozilla-1`, `mozilla-2`

### Phase 3: 边缘情况 (最后导入)
目标：达到 80+ 个测试用例

**特殊格式：**
- `rtl-1`, `rtl-2`, `rtl-3`, `rtl-4` (从右到左语言)
- `svg-parsing`
- `mathjax`
- `links-in-tables`

**复杂布局：**
- `social-buttons`
- `comment-inside-script-parsing`
- `js-link-replacement`

---

## 兼容性度量标准

### Level 1: 基础兼容性 (当前目标)
- 70% 的测试用例能够解析不崩溃
- 50% 的测试用例内容匹配度 > 50%
- 标题提取准确率 > 80%

### Level 2: 良好兼容性
- 85% 的测试用例能够解析
- 70% 的测试用例内容匹配度 > 70%
- 元数据提取（作者、站点名）准确率 > 60%

### Level 3: 完全兼容
- 95% 的测试用例能够解析
- 90% 的测试用例内容匹配度 > 80%
- 与原版 Readability.js 输出基本一致

### 当前状态评估
| 指标 | 当前 | Level 1 目标 | 差距 |
|------|------|-------------|------|
| 测试用例数 | 4 | 20 | -16 |
| 解析成功率 | 100% | 70% | ✅ 超标 |
| 内容匹配度 | 未知 | 50% | 需测量 |
| 标题准确率 | 75% | 80% | 接近 |

---

## 测试质量改进清单

### 立即改进 (本周)
- [x] 删除空 `example()` 测试
- [x] 创建 `StrictMozillaTests` 严格测试集
- [ ] 导入 Phase 1 的 20 个测试用例
- [ ] 修复测试 HTML 长度问题
- [ ] 添加内容匹配度测量工具

### 短期改进 (Phase 2)
- [ ] 实现 HTML 结构对比（而非仅文本）
- [ ] 添加性能基准测试
- [ ] 创建测试通过率仪表板
- [ ] 添加失败测试的详细 diff 输出

### 长期改进 (Phase 3-4)
- [ ] 自动化测试用例导入脚本
- [ ] CI 集成测试报告
- [ ] 与原版 Readability.js 的对比测试
- [ ] 回归测试套件

---

## 快速参考

### 运行特定测试集
```bash
cd Readability

# 只运行基础测试
swift test --filter MozillaTests

# 只运行严格测试
swift test --filter StrictMozillaTests

# 运行全部测试
swift test
```

### 添加新的 Mozilla 测试用例
1. 复制测试目录到 `Resources/test-pages/`
2. 在 `TestLoader.swift` 的 `testNames` 中添加名称
3. 在 `StrictMozillaTests.swift` 中添加对应测试方法
4. 运行测试验证

### 测量内容匹配度
```swift
// 在测试中使用
let matchRatio = calculateContentMatch(
    ourResult: result.content,
    expected: testCase.expectedHTML
)
print("Match ratio: \(matchRatio)")
```

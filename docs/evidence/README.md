# 知行智学（zx-learn）质量证据包

在线教育微服务平台（18 个 Maven 模块 = 16 个可运行后端服务 + 前端 + 2 个公共库）的质量工作留痕。

**本目录只做导航，不复制数据。** 所有数字只有一个来源，就在下方链接指向的原始文档里；若本页与原始文档不一致，以原始文档为准。

---

## 一分钟结论

**工程交付质量较高，功能、安全、数据一致性均有硬证据；生产化配置与可观测性尚未完成，当前不具备对外放行条件。**

- 工程质量评级 **A-**，上线就绪 **C**
- 门禁完成度：A 组 11/11、B 组 1/6、C 组演练 3/5、D 组 4/7、E 组 1/5
- 未关闭的生产阻断：**密钥仍是占位值 / 迁移与备份未执行 / HTTPS 未启用 / 可观测性缺失**

| 维度 | 评级 | 结论 | 证据 |
|---|---|---|---|
| 功能正确性 | A | 329 个单测、460 项后端断言、56 项前端断言全通过；246 个端点 × 3 身份探测无 5xx | [TEST-REPORT.md](../quality/TEST-REPORT.md) §3 |
| **数据一致性** | **A** | 9 条跨库不变量漂移 0；8 个对账断言命中 0 行；空库连跑 2 遍 9/9 | [TEST-REPORT.md](../quality/TEST-REPORT.md) §5 |
| 安全性（代码侧） | B | 13 类垂直越权、19 类水平越权、12 个内部接口、15 项注入、8 项脱敏全部通过；P0 提权链已修复 | [DEFECTS.md](../quality/DEFECTS.md) §7 |
| 性能 | B | 核心接口 P95 43ms（阈值 500ms），200/200 成功、655.3 RPS；秒杀 6 144 QPS、P99 150ms | [PERF.md](../PERF.md) §4 |
| 稳定性 | B | 死信可重放、支付单改为有界 LRU；但死信仅日志 warn、支付单仍为内存态 | [DEFECTS.md](../quality/DEFECTS.md) §7 |
| 工程化 / CI | B | 后端 CI 覆盖构建、单测与 JaCoCo；前端验证仍依赖本地脚本 | `.github/workflows/ci.yml` |
| 可观测性 | C | 健康检查代码具备；死信告警、日志集中收集、上线观察均未配置 | [RELEASE-GATE.md](../quality/RELEASE-GATE.md) E1–E5 |

完整评级口径与风险清单见 [QUALITY-SUMMARY.md](../quality/QUALITY-SUMMARY.md)。

---

## 数据质量专项

本仓库最值得单独看的部分。全部基于 `sql/reconcile.sql` 与跨库 SQL 不变量，可复算。

| 检查 | 方法 | 结果 |
|---|---|---|
| 跨库不变量 | 9 条 SQL（订单 ↔ 课表 ↔ 死信 ↔ 券状态等） | 漂移数全为 0 |
| 三方对账 | `sql/reconcile.sql` 的 8 个断言项 | 修复后命中 0 行 |
| 观察项 | 销量差额、排除项等观察查询 | 与断言项分离，有结果属正常，不得当作失败 |
| 空库可重建 | 9 个迁移脚本在真实空库连续执行 2 遍 | 两遍均 9/9 成功 |

**一处判据修正值得单独说明**：「学习人数」字段兼作展示用营销基线，因此第 8 项**不做绝对相等断言**，只告警「销量小于已确认数」这一真实故障模式。这是判据修正，不是放宽标准（依据：[GO-LIVE-AUDIT-2026-09-16.md](../GO-LIVE-AUDIT-2026-09-16.md) §3.7）。

---

## 口径声明（先读这段，再看数字）

1. **所有性能数字是同机下界**，压测客户端与被测服务同机运行，只用于相对对比与瓶颈定位，不作为生产容量承诺。
2. **数据一致性结论来自演练库**，不等同于生产库已验证。
3. **SSE 优化前后的采样口径不同**，QPS 不可直接比较，可比指标是错误率与最大耗时；TTFT 使用 mock 流式 LLM，不代表真实模型推理时延。
4. **AI 助教当前功能级不可用**（embedding 资源余额不足），不可宣称「知识库已上线」。
5. **不可挂靠邻仓数据**：本仓库的多模块底座（公共库 / 契约库 / 网关鉴权 / 监控栈）被 CodeJudge 复用改造，但两仓库的质量数据各自独立实测，**不可互相套用**。

---

## 怎么读

| 你想知道 | 去哪里 |
|---|---|
| 结论、评级、放行建议、风险排序 | [QUALITY-SUMMARY.md](../quality/QUALITY-SUMMARY.md)（86 行，建议先看这个） |
| 每个数字的实测值与来源 | [TEST-REPORT.md](../quality/TEST-REPORT.md)（123 行，逐行括注出处） |
| 门禁逐项判定 | [RELEASE-GATE.md](../quality/RELEASE-GATE.md) |
| 每个缺陷的现象 / 根因 / 修复 / 验证 | [DEFECTS.md](../quality/DEFECTS.md) |
| 完整 QA 过程与用例明细 | [FULL-QA-REPORT-2026-09-15.md](../FULL-QA-REPORT-2026-09-15.md)（682 行） |
| 测试计划与范围 | [FULL-TEST-PLAN-2026-09-15.md](../FULL-TEST-PLAN-2026-09-15.md) |
| 接口覆盖矩阵 | [API-COVERAGE-MATRIX.md](../API-COVERAGE-MATRIX.md) |
| 上线审计与生产就绪 | [GO-LIVE-AUDIT-2026-09-16.md](../GO-LIVE-AUDIT-2026-09-16.md)、[PRODUCTION-READINESS-2026-09-15.md](../PRODUCTION-READINESS-2026-09-15.md) |
| 秒杀与一致性专项 | [SECKILL.md](../SECKILL.md)、[TRADE-CONSISTENCY.md](../TRADE-CONSISTENCY.md) |

---

## 自己跑一遍

```bash
# 构建 + 单元测试
mvn -B -ntp clean verify

# 接口矩阵与后端断言（需先启动 16 个服务）
bash scripts/verify-full-suite.sh
bash scripts/verify-modules-e2e.sh && bash scripts/verify-admin-student-fixes.sh
bash scripts/verify-lesson-consistency.sh && bash scripts/verify-coupon-status-sync.sh

# 前端类型检查 / 构建 / 断言
bash scripts/verify-frontend.sh
```

预期结果、环境要求与已知陷阱见 [TEST-REPORT.md](../quality/TEST-REPORT.md) §8；对账口径见 `sql/reconcile.sql` 头部说明。

---

## 关于本目录

- `docs/quality/` 同时包含**整改期工作文档**（`REMEDIATION-PLAN.md`、`EXECUTION-CHECKLIST.md`、`PROGRESS-*`）。这些文件记录的是过程中的中间状态，**结论性内容以本 README 与 `QUALITY-SUMMARY.md` 为准**。
- 本目录不含任何凭据、内网地址或个人联系信息；生产密钥类内容已排除在公开范围之外。

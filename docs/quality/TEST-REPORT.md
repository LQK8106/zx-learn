# 知行智学（zx-learn）测试报告

> 快照日期：2026-09-18（工程实测结论）；仓库状态复核：2026-11-16
> 统计口径：只登记仓库内可复算的材料；每个关键数字后括注来源文件。
> 项目关系说明：本仓库的多模块底座（公共库 / 契约库 / 网关鉴权 / 监控栈）被 CodeJudge 项目复用改造；**两个仓库的质量数据各自独立实测，不互相引用**。

## 1. 结论摘要

| 维度 | 结论 | 关键证据 |
|---|---|---|
| 功能 | 18 个 Maven 模块构建成功；单元测试 329 / 0 失败；246 个端点 × 3 身份 = 738 次探测，0 个 5xx | §3 |
| 安全 | 13 类垂直越权、19 类水平越权、12 个内部接口、15 项注入、8 项脱敏全部通过；1 个 P0 提权链已修复 | §3、[DEFECTS.md](./DEFECTS.md) |
| 数据一致性 | 9 条跨库 SQL 不变量漂移全为 0；对账脚本 8 个断言项命中 0 行 | §5 |
| 性能 | 核心接口 P95 43ms（阈值 500ms）；200 请求 200/200 成功、655.3 RPS；秒杀 6 144 QPS / P99 150ms / 0 错误 | §4 |
| 上线就绪 | 工程验证通过；生产密钥、迁移执行、HTTPS 等目标环境动作未完成，**不可直接对外放行** | [RELEASE-GATE.md](./RELEASE-GATE.md) |

## 2. 被测对象与环境

**被测范围**：16 个可运行后端服务（网关、认证、用户、课程、考试、媒资、学习、交易、营销、AI 助教、支付、搜索、点赞、站内信、数据看板、学情）＋ 前端 `zx-web`（Vue 3 + Vite）＋ 2 个公共库 `zx-common`、`zx-api`，合计 18 个 Maven 模块（来源：`TEST_REPORT.md` §1.1）。

| 项 | 内容 | 来源 |
|---|---|---|
| 运行环境 | Windows 11 23H2，AMD Ryzen 9 7940H（8C/16T），15 GB 内存；压测客户端与被测服务同机 | `docs/PERF.md` §1 |
| 基础设施 | MySQL / Redis / RocketMQ / PostgreSQL 均由 Docker 容器提供 | `docker-compose.yml`、`docs/PERF.md` §1 |
| 压测工具 | JMeter 5.6.3；聚合脚本 `perf-test/aggregate-csv.ps1` | `docs/PERF.md` §1 |
| 接口面 | 246 个 HTTP 端点，按匿名 / 学员 / 管理员三种身份各探测一次 | `docs/API-COVERAGE-MATRIX.md` |
| 不在范围内 | 独立压测机容量标定、真实第三方支付回调、多机集群、生产 HTTPS 链路 | `docs/PERF.md` §1、`docs/GO-LIVE-CHECKLIST.md` §D |

## 3. 用例与执行结果

| 层次 | 套件 / 命令 | 用例数 | 结果 | 来源 |
|---|---|---:|---|---|
| 单元测试 | `mvn clean package`（12 个含测试模块） | 329 | 0 失败 / 0 错误 / 0 跳过（4 分 38 秒） | `TEST_REPORT.md` §3.1 |
| 接口矩阵 | `scripts/verify-full-suite.sh` 阶段 2 | 738（246×3） | 246/246 可达，0 个 5xx | `TEST_REPORT.md` §2.1 |
| 后端断言 | 7 个套件合计：full-suite 136、modules-e2e 62、admin-student 82、course-ui 72、lesson-consistency 34、coupon-sync 55、purchase-guard 19 | 460 | 460 / 0 | `TEST_REPORT.md` §3.2 |
| 前端断言 | `scripts/verify-frontend.sh`（含 `vue-tsc` 与 `vite build`） | 56 | 56 / 0 | `TEST_REPORT.md` §3.3 |
| 上线审查复验 | `scripts/verify-go-live-audit.sh` | 全部检查点 | 全部通过 | `docs/verify-go-live-audit-report.txt` |
| 运行期缺陷定向回归 | `logs/tmp/verify_fixes.py` | 15 | 15 / 0 | `docs/PRODUCTION-READINESS-2026-09-15.md` §2 |

合计：**329 个单元测试 + 460 项后端断言 + 56 项前端断言 = 845 项断言**，另有 738 次接口矩阵探测，失败 0。

构建与部署侧同时验证：18 模块全量构建成功；前端 `vue-tsc` 0 错误、`vite build` exit 0，产物 2 988KB、最大分片 933KB（`TEST_REPORT.md` §3.1/§3.3）。

## 4. 性能测试

| 场景 | 负载 / 采样 | 实测 | 门槛 | 判定 | 来源 |
|---|---|---:|---|---|---|
| 核心接口时延 | 20 并发 × 10 轮 | P95 **43ms** | ≤ 500ms | ✅ | `TEST_REPORT.md` §2.4 |
| 并发成功率 | 200 请求 | **200/200**，0 个 5xx、0 连接失败 | 100% | ✅ | 同上 |
| 并发吞吐 | 20 并发 | **655.3 RPS** | ≥ 50 RPS | ✅ | 同上 |
| 同口径对照（修正测试噪声后） | 20 并发 | 501.5 RPS、P95 61ms | — | ✅ | `docs/FULL-QA-REPORT-2026-09-15.md` §5.x |
| 优惠券秒杀（持续吞吐） | 500 并发 × 100 循环 = 50 000 采样 | 峰值 **6 144 QPS**，P99 **150ms**，0 错误 | 无超发、无重复领取 | ✅ | `docs/PERF.md` §4.2、§4.3 |
| AI 助教 SSE | 50 / 100 / 200 / 500 并发，每档 3 000 连接 | 优化后四档错误率 **0%**，端到端最大 107–128ms | — | ✅（相对优化前） | `docs/PERF.md` §5.1 |
| SSE 首包 | 同上 | TTFT P99 稳定 **17–18ms** | — | ✅（mock 口径） | `docs/PERF.md` §5.2 |
| 同步下单（对照） | — | 吞吐约为课程详情读路径的 1/5 | — | 基准记录 | `docs/PERF.md` §6 |

必须同时说明的口径（来源：`docs/PERF.md` §1、§5.1）：

1. 压测机与被测机同机，绝对值偏保守且波动大；本报告只用于相对对比与瓶颈定位。
2. SSE 优化前后的采样口径不同（高频建连 vs 每档 3 000 受控连接），QPS 不可直接比较；**错误率与最大耗时才是可比指标**。
3. `TTFT` 使用 mock 流式 LLM，只验证服务端流式链路开销，不代表真实模型推理时延。

## 5. 数据质量验证

| 检查 | 方法 | 结果 | 来源 |
|---|---|---|---|
| 跨库不变量 | 9 条 SQL 不变量（订单↔课表↔死信↔券状态等） | 漂移数全为 0 | `docs/FULL-QA-REPORT-2026-09-15.md` §6.1 |
| 三方对账 | `sql/reconcile.sql` 的 8 个断言项 | 修复后命中 **0 行** | `docs/GO-LIVE-AUDIT-2026-09-16.md` §3.7 |
| 观察项 | 销量差额、排除项等观察查询 | 与断言项分离，有结果属正常；不得当作失败 | `sql/reconcile.sql` 头部口径说明 |
| 空库可重建 | 9 个迁移脚本在真实空库连续执行 2 遍 | 两遍均 9/9 成功 | `docs/GO-LIVE-CHECKLIST.md` A 组 |
| 重建后数据 | 课程 13 门、目录 78 行、空讲义 0、空章节名 0、孤儿目录 0、`cover_url` 列宽 512 | 全部符合预期 | 同上；`docs/PRODUCTION-READINESS-2026-09-15.md` GL-003~GL-005 |

> “学习人数”字段兼作展示用营销基线，因此第 8 项**不做绝对相等断言**，只告警“销量小于已确认数”的真实故障模式；这是判据修正，不是放宽标准（`docs/GO-LIVE-AUDIT-2026-09-16.md` §3.7）。

## 6. 缺陷

| 类别 | 数量 | 状态 |
|---|---:|---|
| QA 阶段（BUG-001~011） | 11（P0 1 / P1 4 / P2 4 / P3 2） | 全部修复 |
| 上线准备阶段（GL-001~007） | 7（P0 2 / P1 3 / P2 2） | 全部修复 |
| 上线前复测运行期（B-001~005） | 5（P0 1 / P1 2 / P2 2） | 全部修复 |
| 深层问题（D-001/002） | 2（P0 2） | 全部修复 |
| 修复引入的回归（R-001） | 1 | 已解决 |
| 测试侧缺陷（脚本/夹具） | 4（P1 2 / P2 2） | 全部修复 |

逐条现象、根因、修复与验证见 [DEFECTS.md](./DEFECTS.md)。

> 统计口径说明：`docs/GO-LIVE-CHECKLIST.md`（2026-09-16）按“QA 11 + 上线准备 5 = 16”统计，未计入 GL-001~007 与 D-001/002；本文以 `docs/PRODUCTION-READINESS-2026-09-15.md` §1 的逐项记录为准。

## 7. 遗留风险与不适用边界

1. **生产密钥未替换**：`.env` 模板仍是开发占位值，JWT / 支付回调 / 数据库口令必须重新生成（`docs/GO-LIVE-CHECKLIST.md` B 组）。
2. **目标环境动作未执行**：迁移、备份、HTTPS、死信告警均需在生产执行（同清单 C/D 组）。
3. **RAG 向量化不可用**：配置缺陷已修，但 embedding 资源包余额不足（错误码 1113），需充值或更换供应商（`docs/GO-LIVE-AUDIT-2026-09-16.md` §一）。
4. **教师可自助注册**：已关闭（2026-11-16）：网关白名单移除 `/teachers/register`、`TeacherController` 删除该端点、注册页仅保留学员；运行时匿名 401/404 断言待启动栈验证（见 `PROGRESS-zx-learn-20261116.md`）。
5. **支付单仍是内存态**：已从无界增长改为有界 LRU，生产仍应落库（`docs/FULL-QA-REPORT-2026-09-15.md` §6.2）。
6. **JWT 无双钥轮换**：换钥会使全部已签发 token 失效，零掉线方案未实现（`docs/GO-LIVE-CHECKLIST.md` F 组）。
7. **容量只有本机下界**：未在独立压测机复测，也未做 MySQL 慢查询回归（`docs/GO-LIVE-CHECKLIST.md` F 组）。
8. **源码入库状态已改善**：2026-09-16 审查时 263 项未提交；2026-11-20 质量文档与证据包（`docs/quality/`、`docs/evidence/`）已入库。此后工作区仍有未提交修改（环境配置与部分源码调整），其范围与数量随时间变化，不在本文档内固化统计。

## 8. 复现方式

```bash
# 构建 + 单元测试
mvn -B -ntp clean verify

# 接口矩阵与后端断言（需先启动 16 个服务）
bash scripts/verify-full-suite.sh
bash scripts/verify-modules-e2e.sh
bash scripts/verify-admin-student-fixes.sh
bash scripts/verify-course-ui-and-catalogue.sh
bash scripts/verify-lesson-consistency.sh
bash scripts/verify-coupon-status-sync.sh
bash scripts/verify-purchase-guard.sh

# 前端类型检查 / 构建 / 断言
bash scripts/verify-frontend.sh

# 上线审查复验
bash scripts/verify-go-live-audit.sh
```

压测原始数据与聚合方法见 `docs/PERF.md`、`perf-test/README.md`；对账口径见 `sql/reconcile.sql` 头部说明。

# SQL开发全流程规范（经验库）

> 本文档是从"业务需求"到"可执行SQL"的完整标准化指南。  
> 适用系统：用友NC ERP + StarRocks 数据仓库  
> 版本：v1.0 | 日期：2026-03-03

---

## 一、工程目录结构规范

```
starrocks_ai/
├── docs/                      # 文档中心
│   ├── 数据字典.md                 表结构与字段定义
│   ├── 数据库表关系图.md           表关系、主外键、关联模式
│   ├── SQL编码规范.md              SQL编码规则速查手册
│   ├── SQL开发全流程规范.md        【本文档】开发流程经验库
│   ├── 物化视图设计.md             物化视图架构设计(StarRocks 3.5)
│   └── BI报表需求清单.md           报表需求全量清单
│
├── 视图/                      # 物化视图DDL
│   ├── 00_刷新所有视图.sql
│   ├── 01_MV_SALES_DETAIL.sql ~ 08_MV_CUSTOMER_ACTIVITY.sql
│   └── ...
│
├── 报表SQL/                   # 报表查询SQL（正式产出）
│   ├── README.md
│   ├── {编号}_{报表名}.sql              物化视图版本（推荐）
│   └── {编号}_{报表名}_原始版本.sql     原始表版本（对数验证）
│
├── 案例/                      # 历史SQL案例（参考资料）
│   └── *.sql
│
└── .cursor/rules/             # AI辅助开发规则
    └── sql-development.mdc
```

### 文件命名规范

| 类别 | 命名规则 | 示例 |
|------|---------|------|
| 物化视图DDL | `{序号}_{视图名}.sql` | `01_MV_SALES_DETAIL.sql` |
| 报表SQL | `{需求编号}_{报表名称}.sql` | `01_销售业绩报表.sql` |
| 原始版本 | `{编号}_{报表名称}_原始版本.sql` | `01_销售业绩报表_原始版本.sql` |
| 工具脚本 | `00_{功能}.sql` / `99_{功能}.sql` | `00_刷新所有视图.sql` |

**序号规则**：与 `docs/BI报表需求清单.md` 中的报表编号一一对应。

---

## 二、开发全流程（六阶段）

```
需求分析 → 方案设计 → 视图开发 → 报表SQL开发 → 验证测试 → 交付上线
  (1)        (2)        (3)          (4)          (5)        (6)
```

---

### 阶段1：需求分析

**输入**：业务方口头/文档描述  
**输出**：需求条目录入 `docs/BI报表需求清单.md`

#### 1.1 需求采集模板

每个报表需求必须明确以下要素：

```markdown
### X.X 报表名称 ⭐优先级(⭐/⭐⭐/⭐⭐⭐)
**业务价值**: 一句话说明这个报表解决什么业务问题

| 报表项       | 内容 |
|-------------|------|
| **分析维度** | 时间粒度、组织维度、商品维度等 |
| **核心指标** | 需要展示的数值指标 |
| **对比分析** | 同比/环比/排名/占比等 |
| **预警规则** | 阈值条件和触发动作 |
| **更新频率** | 实时/每日/每周/每月 |
| **数据来源** | 主要业务表名 |
```

#### 1.2 需求分析检查清单

- [ ] 明确**谁**在**什么场景**下使用这个报表
- [ ] 明确所有**分析维度**（可以按什么角度切数据）
- [ ] 明确所有**核心指标**及其**计算公式**
- [ ] 明确**时间范围**（实时数据 / T+1 / 历史对比）
- [ ] 明确**数据来源表**（确认在数据字典中存在）
- [ ] 明确**更新频率**（决定是否需要物化视图）
- [ ] 与业务方确认**赠品**是否参与计算
- [ ] 与业务方确认是否需要排除**特殊编码商品**（如98开头）
- [ ] 与业务方确认**客商范围**（客户/供应商/全部）

#### 1.3 指标公式标准化

所有报表中出现的指标必须使用统一的计算口径：

| 指标 | 标准计算公式 | 说明 |
|------|-------------|------|
| **销售流水** | 赠品→0；有自定义单价→`vbodydef5/(1+ntaxrate*0.01)*noutnum`；否则→`noriginalcurmny/(1+ntaxrate*0.01)` | 不含税金额 |
| **销售成本** | `ncostmny` | 直接取结算明细的成本金额 |
| **毛利** | `销售流水 - 销售成本` | |
| **毛利率** | `毛利 / 销售流水 * 100`（流水为0时返回0） | 百分比，保留2位 |
| **结存单价** | 优先 `nabprice`，否则 `noutmny/noutnum`（除零保护） | |
| **库存金额** | `结存数量 * 结存单价` | |
| **超期天数** | `DATEDIFF(CURDATE(), DATE_ADD(单据日期, INTERVAL 账期天数 DAY))` | |
| **同比增长率** | `(本期 - 去年同期) / 去年同期 * 100`（去年为0返回NULL） | |
| **环比增长率** | `(本期 - 上期) / 上期 * 100`（上期为0返回NULL） | |

> **核心原则**：同一个指标在所有报表中必须用同一套公式，绝不允许不同报表用不同口径。

---

### 阶段2：方案设计

**输入**：需求条目  
**输出**：确定数据流路径（哪些原始表 → 是否需要物化视图 → 报表SQL结构）

#### 2.1 判断是否需要物化视图

```
是否满足以下任一条件？
  ├─ 多个报表复用同一组多表JOIN → 需要物化视图
  ├─ 查询涉及3张以上表关联 → 推荐物化视图
  ├─ 数据量大(>50万行)且需频繁查询 → 需要物化视图
  ├─ 需要复杂计算（如流水/毛利公式） → 推荐物化视图
  └─ 简单单表/双表查询 → 不需要
```

#### 2.2 物化视图设计规范

**命名规范**：`MV_{业务域}_{数据粒度}`

| 业务域 | 粒度 | 视图名 | 示例用途 |
|-------|------|--------|---------|
| SALES | DETAIL | MV_SALES_DETAIL | 销售明细宽表 |
| SALES | DAILY | MV_SALES_DAILY | 销售日汇总 |
| SALES | MONTHLY | MV_SALES_MONTHLY | 销售月汇总 |
| INVENTORY | SNAPSHOT | MV_INVENTORY_SNAPSHOT | 库存快照 |
| RECEIVABLE | SUMMARY | MV_RECEIVABLE_SUMMARY | 应收汇总 |
| CUSTOMER | MASTER | MV_CUSTOMER_MASTER | 客户主数据 |
| CUSTOMER | ACTIVITY | MV_CUSTOMER_ACTIVITY | 客户活跃度 |
| PRODUCT | MASTER | MV_PRODUCT_MASTER | 商品主数据 |

**视图DDL标准结构**：

```sql
-- =====================================================
-- 物化视图{序号}: {视图中文名} ({视图英文名})
-- 用途: {一句话说明}
-- 更新频率: {每日/每周/每月}
-- 服务报表: {报表1}、{报表2}、...
-- =====================================================

CREATE MATERIALIZED VIEW {视图名}
DISTRIBUTED BY HASH({主键字段}) BUCKETS 32
REFRESH ASYNC
AS
SELECT
    -- === 主键和时间 ===
    ...
    -- === 维度字段（中文别名） ===
    ...
    -- === 度量字段（中文别名） ===
    ...
FROM 
    {主表} {别名}
    {关联语句}
WHERE 
    {标准过滤条件};

-- 创建索引
CREATE INDEX idx_{缩写}_{字段} ON {视图名}({字段});
```

**字段别名规范**：物化视图的输出字段统一使用中文别名，后续报表SQL直接引用中文字段名，提高可读性。

#### 2.3 视图层级依赖关系

```
Layer 0 - 原始表
    IC_ONHANDNUM, SO_SQUAREDETAIL, BD_CUMANDOC, ...

Layer 1 - 明细宽表视图（直接从原始表构建）
    MV_SALES_DETAIL      ← SO_SQUAREDETAIL + 维度表
    MV_INVENTORY_SNAPSHOT ← IC_ONHANDNUM + 维度表 + 成本表
    MV_RECEIVABLE_SUMMARY ← SO_SQUARE + 维度表
    MV_CUSTOMER_MASTER    ← BD_CUMANDOC + 维度表 + 信用表
    MV_PRODUCT_MASTER     ← BD_INVBASDOC + BD_INVMANDOC

Layer 2 - 汇总视图（可从Layer 1聚合，也可直接从原始表聚合）
    MV_SALES_DAILY        ← 直接聚合原始表（或从MV_SALES_DETAIL聚合）
    MV_SALES_MONTHLY      ← 直接聚合原始表（或从MV_SALES_DETAIL聚合）
    MV_CUSTOMER_ACTIVITY  ← SO_SALEINVOICE + 维度表

Layer 3 - 报表SQL（从视图查询）
    01_销售业绩报表.sql   ← MV_SALES_DETAIL + MV_SALES_MONTHLY
    02_库存监控看板.sql    ← MV_INVENTORY_SNAPSHOT
    ...
```

> **原则**：刷新顺序必须遵循依赖关系，Layer 1 先刷新，Layer 2 后刷新。

---

### 阶段3：视图开发

#### 3.1 开发步骤

1. **确定主表**：根据业务场景选择正确的主表
2. **确定关联表**：按数据库表关系图添加所需维度表
3. **编写JOIN**：严格按照主外键关系，遵循过滤条件规范
4. **定义输出字段**：使用中文别名，计算字段用ROUND
5. **添加索引**：为常用查询字段创建索引
6. **本地验证**：先用SELECT测试查询结果正确性
7. **创建视图**：执行CREATE MATERIALIZED VIEW
8. **登记更新**：在 `00_刷新所有视图.sql` 中添加刷新语句

#### 3.2 主表选择速查表

| 业务场景 | 主表 | 说明 |
|---------|------|------|
| 销售毛利分析 | SO_SQUAREDETAIL | 销售结算明细，含成本 |
| 销售发票明细 | SO_SALEINVOICE_B | 销售发票附表 |
| 销售订单查询 | SO_SALE | 销售订单主表 |
| 库存查询 | IC_ONHANDNUM | 现存量表 |
| 成本查询 | IA_GENERALLEDGER | 存货总账 |
| 出入库统计 | IC_GENERAL_H | 出入库单主表 |
| 调拨查询 | TO_BILL | 调拨单主表 |
| 应收结算 | SO_SQUARE | 销售结算主表 |
| 应收明细 | ARAP_DJFB | 应收应付分表 |
| 客户信息 | BD_CUMANDOC | 客商管理档案（注意：不是BD_CUBASDOC） |
| 商品信息 | BD_INVBASDOC + BD_INVMANDOC | 存货档案+管理档案 |

---

### 阶段4：报表SQL开发

#### 4.1 报表SQL文件标准结构

```sql
-- =====================================================
-- 报表{编号}: {报表名称}
-- 业务价值: {一句话}
-- 更新频率: {频率}
-- 依赖视图: {视图1}, {视图2}
-- =====================================================


-- =====================================================
-- {编号}.1 {子查询名称}（{简要说明}）
-- =====================================================
SELECT 
    ...
FROM {视图名}
WHERE {条件}
GROUP BY {分组}
ORDER BY {排序};


-- =====================================================
-- {编号}.2 {子查询名称}
-- =====================================================
...
```

#### 4.2 报表SQL编写规范

**格式规范**：
- 关键字大写：`SELECT`, `FROM`, `WHERE`, `GROUP BY`, `ORDER BY`, `INNER JOIN`, `LEFT JOIN`
- 每个SELECT字段单独一行，逗号在行首（可选）或行尾
- 每个JOIN单独起段，ON条件对齐缩进
- WHERE条件每个AND单独一行

**安全规范**：
- 所有除法必须有除零保护（CASE WHEN 分母=0 THEN 0/NULL ELSE ... END）
- 所有可能为NULL的字段使用 COALESCE 或 IFNULL
- 金额计算统一 ROUND(..., 2)
- 百分比计算统一 ROUND(... * 100, 2)

**同比/环比模板**：

```sql
WITH 本期数据 AS (
    SELECT {维度}, SUM({指标}) AS 本期值
    FROM {视图}
    WHERE {本期条件}
    GROUP BY {维度}
),
对比数据 AS (
    SELECT {维度}, SUM({指标}) AS 对比值
    FROM {视图}
    WHERE {对比期条件}
    GROUP BY {维度}
)
SELECT 
    COALESCE(本期.{维度}, 对比.{维度}) AS {维度},
    ROUND(COALESCE(本期.本期值, 0), 2) AS 本期值,
    ROUND(COALESCE(对比.对比值, 0), 2) AS 对比值,
    CASE 
        WHEN COALESCE(对比.对比值, 0) = 0 THEN NULL
        ELSE ROUND((COALESCE(本期.本期值, 0) - COALESCE(对比.对比值, 0)) 
                   / COALESCE(对比.对比值, 0) * 100, 2)
    END AS 增长率
FROM 本期数据 本期
FULL OUTER JOIN 对比数据 对比
    ON 本期.{维度} = 对比.{维度}
ORDER BY 本期值 DESC;
```

**排名模板**：

```sql
SELECT 
    {维度字段},
    ROUND(SUM({指标}), 2) AS 指标值,
    RANK() OVER (ORDER BY SUM({指标}) DESC) AS 排名,
    RANK() OVER (PARTITION BY {分组维度} ORDER BY SUM({指标}) DESC) AS 组内排名
FROM {视图}
WHERE {条件}
GROUP BY {维度字段}
ORDER BY 指标值 DESC;
```

#### 4.3 产出双版本规则

每个报表 **必须** 产出两个版本：

| 版本 | 文件名 | 用途 | 数据时效 |
|------|--------|------|---------|
| 物化视图版 | `{编号}_{名称}.sql` | **生产使用**，查询快 | T+1（依赖视图刷新） |
| 原始版本 | `{编号}_{名称}_原始版本.sql` | **验证对数**、实时查询 | 实时 |

两个版本的查询结果必须一致（在视图刷新后）。

---

### 阶段5：验证测试

#### 5.1 SQL正确性检查清单

**结构检查**：
- [ ] 表名全部大写
- [ ] 无数据库名称前缀（不用 `nc5x.`）
- [ ] 所有输出字段都有中文别名
- [ ] SELECT中非聚合字段全部出现在GROUP BY中
- [ ] FULL OUTER JOIN的ON条件完整

**过滤条件检查**：
- [ ] 单据表（SO_/IC_/TO_/ARAP_开头）添加了 `pk_corp = '1006'`
- [ ] 管理档案表（BD_CUMANDOC/BD_INVMANDOC/BD_PAYTERM/SO_CUCREDIT）添加了 `pk_corp = '1006'`
- [ ] 基础档案表（BD_INVBASDOC/BD_STORDOC/BD_CUBASDOC/BD_PSNDOC/BD_DEPTDOC）**没有**添加 `pk_corp`
- [ ] 所有表都添加了 `dr = 0`
- [ ] 客户查询包含 `custflag IN ('0', '2')`
- [ ] 销售指标排除了赠品（`blargessflag` 处理）
- [ ] 排除了特殊编码商品（98开头或指定编码列表）

**计算检查**：
- [ ] 除法运算有除零保护
- [ ] 金额使用 `ROUND(..., 2)`
- [ ] 百分比使用 `ROUND(... * 100, 2)`
- [ ] 流水公式统一（vbodydef5优先逻辑）
- [ ] NULL值有 `COALESCE`/`IFNULL` 处理

**关联检查**（按 `docs/数据库表关系图.md`）：
- [ ] 存货：`BD_INVBASDOC.pk_invbasdoc = BD_INVMANDOC.pk_invbasdoc`
- [ ] 现存量→存货：`IC_ONHANDNUM.cinvbasid = BD_INVBASDOC.pk_invbasdoc`
- [ ] 现存量→存货管理：`IC_ONHANDNUM.cinventoryid = BD_INVMANDOC.pk_invmandoc`
- [ ] 现存量→仓库：`IC_ONHANDNUM.cwarehouseid = BD_STORDOC.pk_stordoc`
- [ ] 现存量→成本：`cinventoryid = cinventoryid AND ccalbodyid = crdcenterid`（双字段！）
- [ ] 客商管理→客商档案：`BD_CUMANDOC.pk_cubasdoc = BD_CUBASDOC.pk_cubasdoc`
- [ ] 结算→客户：`SO_SQUAREDETAIL.ccustomerid = BD_CUMANDOC.pk_cumandoc`
- [ ] 结算→存货管理：`SO_SQUAREDETAIL.cinventoryid = BD_INVMANDOC.pk_invmandoc`
- [ ] 结算→业务员：`SO_SQUAREDETAIL.cemployeeid = BD_PSNDOC.pk_psndoc`
- [ ] 结算→部门：`SO_SQUAREDETAIL.cdeptid = BD_DEPTDOC.pk_deptdoc`
- [ ] 部门层级：`BD_DEPTDOC.pk_fathedept = BD_DEPTDOC.pk_deptdoc`（自关联）
- [ ] 地区信息：`BD_AREACL.pk_fatherarea = BD_AREACL.pk_areacl`（自关联，子查询）
- [ ] 信用额度：关联两次 `SO_CUCREDIT`（可欠款 + 临时）

#### 5.2 数据验证方法

**方法1：双版本对数**
```sql
-- 物化视图版本的总额
SELECT SUM(销售流水) FROM MV_SALES_DETAIL WHERE 年月 = '2026-02';

-- 原始表版本的总额（应与上面一致）
SELECT SUM(
    CASE WHEN sq.blargessflag = 'Y' THEN 0
         WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 
         THEN ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
         ELSE ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
    END
) FROM SO_SQUAREDETAIL sq
INNER JOIN BD_INVMANDOC invman ON sq.cinventoryid = invman.pk_invmandoc AND invman.pk_corp = '1006' AND invman.dr = 0
INNER JOIN BD_INVBASDOC invbas ON invman.pk_invbasdoc = invbas.pk_invbasdoc AND invbas.dr = 0
WHERE sq.pk_corp = '1006' AND sq.dr = 0
  AND DATE_FORMAT(sq.dmakedate, '%Y-%m') = '2026-02'
  AND SUBSTR(invbas.invcode, 1, 2) != '98'
  AND invbas.width IN ('兼容', '原装', '打印机', '电脑PC');
```

**方法2：行数验证**
```sql
-- 检查视图行数是否合理
SELECT COUNT(*) AS 总行数, COUNT(DISTINCT 客户主键) AS 客户数 FROM MV_SALES_DETAIL;
```

**方法3：边界值检查**
```sql
-- 检查是否有异常数据
SELECT * FROM MV_SALES_DETAIL WHERE 销售流水 < 0 AND 是否赠品 = 'N' LIMIT 10;
SELECT * FROM MV_SALES_DETAIL WHERE 销售成本 IS NULL LIMIT 10;
```

---

### 阶段6：交付上线

#### 6.1 交付物清单

每个报表需求完成后，必须产出以下文件：

| 交付物 | 位置 | 必须 |
|--------|------|------|
| 物化视图DDL | `视图/{序号}_{视图名}.sql` | 如果需要新视图 |
| 报表SQL（MV版） | `报表SQL/{编号}_{名称}.sql` | 是 |
| 报表SQL（原始版） | `报表SQL/{编号}_{名称}_原始版本.sql` | 是 |
| 刷新脚本更新 | `视图/00_刷新所有视图.sql` | 如果有新视图 |
| 需求清单更新 | `docs/BI报表需求清单.md` | 标记已完成 |
| 报表README更新 | `报表SQL/README.md` | 添加新报表说明 |

#### 6.2 上线检查清单

- [ ] 物化视图DDL已在测试环境执行成功
- [ ] 物化视图已刷新，数据验证通过
- [ ] 两个版本的报表SQL查询结果一致
- [ ] 查询性能满足要求（MV版 < 5秒）
- [ ] `00_刷新所有视图.sql` 已更新
- [ ] `报表SQL/README.md` 已更新
- [ ] `docs/BI报表需求清单.md` 已标记完成

---

## 三、SQL编码规范速查

### 3.1 pk_corp 过滤速查表

| 表名 | 类型 | 需要pk_corp |
|------|------|------------|
| SO_SALE / SO_SALEINVOICE / SO_SQUARE | 单据主表 | **是** |
| SO_SALEINVOICE_B / SO_SQUARE_B / SO_SQUAREDETAIL | 单据附表/明细 | **是** |
| IC_ONHANDNUM / IC_GENERAL_H | 业务表 | **是** |
| IA_GENERALLEDGER | 业务表 | **是** |
| TO_BILL / ARAP_DJFB | 单据表 | **是** |
| BD_CUMANDOC / BD_INVMANDOC | 管理档案 | **是** |
| BD_PAYTERM / SO_CUCREDIT | 管理档案 | **是** |
| BD_INVBASDOC / BD_STORDOC / BD_CUBASDOC | 基础档案 | **否** |
| BD_PSNDOC / BD_DEPTDOC / BD_AREACL | 基础档案 | **否** |
| BD_BILLTYPE / BD_BUSITYPE / BD_DEFDOC / SM_USER | 系统基础表 | **否** |

**口诀**：单据表和管理档案要加 `pk_corp`，基础档案不加。

### 3.2 JOIN类型选择

| 场景 | JOIN类型 | 说明 |
|------|---------|------|
| 主附表关联 | INNER JOIN | 附表必有主表记录 |
| 存货档案→存货管理 | INNER JOIN | 管理档案是必须的 |
| 业务表→人员/部门 | LEFT JOIN | 可能缺失 |
| 业务表→客商 | LEFT JOIN | 散户可能无客商记录 |
| 业务类型 | LEFT JOIN | 部分单据无业务类型 |
| 地区信息 | LEFT JOIN（子查询） | 部分客户无地区 |
| 信用额度 | LEFT JOIN（两次） | 区分可欠款和临时 |

### 3.3 标准过滤条件

```sql
-- 每个表都要加
AND {别名}.dr = 0

-- 单据表和管理档案要加
AND {别名}.pk_corp = '1006'

-- 客户查询
AND cuman.custflag IN ('0', '2')

-- 排除赠品（看业务需要）
AND IFNULL(sq.blargessflag, 'N') = 'N'
-- 或在计算中处理: CASE WHEN blargessflag = 'Y' THEN 0 ELSE ... END

-- 排除特殊编码商品（98开头）
AND SUBSTR(invbas.invcode, 1, 2) != '98'

-- 排除封存数据
AND {别名}.sealflag <> '1'

-- 只保留主要品类
AND invbas.width IN ('兼容', '原装', '打印机', '电脑PC')

-- 排除零库存
AND oh.nonhandnum != 0

-- 出入库已审批
AND h.fbillflag >= 3

-- 应收未核销
AND fb.djdl = 'ys' AND fb.isverifyfinished = 'N'

-- ★ 单据表时间戳控制（只取近两年数据）
-- 适用表: SO_SALE, SO_SALEINVOICE, SO_SQUARE, SO_SQUAREDETAIL,
--         IC_GENERAL_H, TO_BILL, ARAP_DJFB
-- 这些单据表数据量大，必须加 ts 时间范围避免全表扫描
AND sq.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
```

### 3.4 销售流水标准公式

此公式在所有视图和报表中必须保持一致：

```sql
CASE 
    WHEN sq.blargessflag = 'Y' THEN 0
    WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
        ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
    ELSE
        ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
END AS 销售流水
```

**逻辑**：
1. 赠品 → 流水为0
2. 有自定义单价(vbodydef5) → 用自定义单价 × 数量去税
3. 否则 → 用原币无税金额去税

### 3.5 成本单价标准公式

```sql
COALESCE(
    gl.nabprice,                          -- 优先：结存单价
    CASE 
        WHEN gl.noutnum = 0 OR gl.noutnum IS NULL THEN 0 
        ELSE ROUND(gl.noutmny / gl.noutnum, 2) 
    END                                    -- 备选：发出金额/发出数量
) AS 结存单价
```

---

## 四、常用关联模式速查（8种标准模式）

### 模式1：销售毛利分析（最常用）
```sql
FROM SO_SQUAREDETAIL sq
    INNER JOIN BD_INVMANDOC invman 
        ON sq.cinventoryid = invman.pk_invmandoc
        AND invman.pk_corp = '1006' AND invman.dr = 0
    INNER JOIN BD_INVBASDOC invbas 
        ON invman.pk_invbasdoc = invbas.pk_invbasdoc
        AND invbas.dr = 0
    LEFT JOIN BD_CUMANDOC cuman 
        ON sq.ccustomerid = cuman.pk_cumandoc
        AND cuman.pk_corp = '1006' AND cuman.dr = 0
    LEFT JOIN BD_CUBASDOC cumbase 
        ON cuman.pk_cubasdoc = cumbase.pk_cubasdoc
        AND cumbase.dr = 0
    LEFT JOIN BD_PSNDOC psn 
        ON sq.cemployeeid = psn.pk_psndoc AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept 
        ON sq.cdeptid = dept.pk_deptdoc AND dept.dr = 0
    LEFT JOIN BD_DEPTDOC fdept 
        ON dept.pk_fathedept = fdept.pk_deptdoc AND fdept.dr = 0
    LEFT JOIN BD_BUSITYPE btp 
        ON sq.cbiztype = btp.pk_busitype AND btp.dr = 0
WHERE sq.pk_corp = '1006' AND sq.dr = 0
```

### 模式2：库存查询（含成本）
```sql
FROM IC_ONHANDNUM oh
    INNER JOIN BD_INVBASDOC inv 
        ON oh.cinvbasid = inv.pk_invbasdoc AND inv.dr = 0
    INNER JOIN BD_STORDOC stor 
        ON oh.cwarehouseid = stor.pk_stordoc AND stor.dr = 0
    LEFT JOIN BD_INVMANDOC invman
        ON inv.pk_invbasdoc = invman.pk_invbasdoc
        AND invman.pk_corp = '1006' AND invman.dr = 0
    LEFT JOIN IA_GENERALLEDGER gl 
        ON invman.pk_invmandoc = gl.cinventoryid
        AND oh.ccalbodyid = gl.crdcenterid  -- 双字段关联！
        AND gl.dr = 0
WHERE oh.pk_corp = '1006' AND oh.dr = 0
```

### 模式3：客户完整信息（含账期+信用）
```sql
FROM BD_CUMANDOC cuman
    INNER JOIN BD_CUBASDOC cumbase 
        ON cumbase.pk_cubasdoc = cuman.pk_cubasdoc AND cumbase.dr = 0
    LEFT JOIN BD_PAYTERM term 
        ON cuman.pk_payterm = term.pk_payterm
        AND term.pk_corp = '1006' AND term.dr = 0
    LEFT JOIN BD_PSNDOC psn 
        ON psn.pk_psndoc = cuman.pk_resppsn1 AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept 
        ON cuman.pk_respdept1 = dept.pk_deptdoc AND dept.dr = 0
    LEFT JOIN BD_DEPTDOC fdept 
        ON dept.pk_fathedept = fdept.pk_deptdoc AND fdept.dr = 0
    LEFT JOIN SO_CUCREDIT redit 
        ON cumbase.pk_cubasdoc = redit.pk_cubasdoc
        AND redit.climittypeid = '0001A110000000002EXU'
        AND redit.vcredittypename = '2' AND redit.dr = 0
    LEFT JOIN SO_CUCREDIT redits 
        ON cumbase.pk_cubasdoc = redits.pk_cubasdoc
        AND redits.climittypeid = '0001A110000000002EXV'
        AND redits.vcredittypename = '2' AND redits.dr = 0
    LEFT JOIN (
        SELECT cl.pk_areacl, c.areaclname AS sf, cl.areaclname AS cs
        FROM BD_AREACL c
        INNER JOIN BD_AREACL cl ON c.pk_areacl = cl.pk_fatherarea
    ) dq ON cumbase.pk_areacl = dq.pk_areacl
WHERE cuman.pk_corp = '1006' AND cuman.dr = 0
    AND cuman.custflag IN ('0', '2')
```

### 模式4：应收账龄
```sql
FROM ARAP_DJFB fb
    LEFT JOIN BD_PAYTERM ter 
        ON fb.sfkxyh = ter.pk_payterm AND ter.pk_corp = '1006' AND ter.dr = 0
    LEFT JOIN BD_CUBASDOC cub 
        ON fb.hbbm = cub.pk_cubasdoc AND cub.dr = 0
    LEFT JOIN V_ZLW_CUST cu 
        ON cub.pk_cubasdoc = cu.pk_cubasdoc
WHERE fb.pk_corp = '1006' AND fb.dr = 0
    AND fb.djdl = 'ys' AND fb.isverifyfinished = 'N'
```

### 模式5：销售发票明细
```sql
FROM SO_SALEINVOICE ii
    INNER JOIN SO_SALEINVOICE_B ib ON ib.csaleid = ii.csaleid AND ib.dr = 0
    INNER JOIN BD_INVBASDOC inv ON ib.cinvbasdocid = inv.pk_invbasdoc AND inv.dr = 0
    LEFT JOIN SO_SALE od ON ib.coriginalbillcode = od.vreceiptcode
        AND od.pk_corp = '1006' AND od.dr = 0
    LEFT JOIN BD_CUMANDOC cum ON ii.creceiptcustomerid = cum.pk_cumandoc
        AND cum.pk_corp = '1006' AND cum.dr = 0
    LEFT JOIN BD_CUBASDOC cub ON cum.pk_cubasdoc = cub.pk_cubasdoc AND cub.dr = 0
    LEFT JOIN BD_PSNDOC psn ON ii.cemployeeid = psn.pk_psndoc AND psn.dr = 0
WHERE ii.pk_corp = '1006' AND ii.dr = 0
```

### 模式6：出入库
```sql
FROM IC_GENERAL_H h
    INNER JOIN IC_GENERAL_B b ON h.cgeneralhid = b.cgeneralhid AND b.dr = 0
    INNER JOIN BD_INVBASDOC inv ON b.cinvbasid = inv.pk_invbasdoc AND inv.dr = 0
    INNER JOIN BD_BILLTYPE bt ON h.cbilltypecode = bt.pk_billtypecode AND bt.dr = 0
    LEFT JOIN BD_STORDOC stor ON h.cwarehouseid = stor.pk_stordoc AND stor.dr = 0
    LEFT JOIN SM_USER us ON h.coperatorid = us.cuserid
WHERE h.pk_corp = '1006' AND h.dr = 0 AND h.fbillflag >= 3
```

### 模式7：调拨单
```sql
FROM TO_BILL zb
    INNER JOIN TO_BILL_B db ON zb.cbillid = db.cbillid AND db.dr = 0
    INNER JOIN BD_STORDOC rc ON db.cinwhid = rc.pk_stordoc AND rc.dr = 0
    INNER JOIN BD_STORDOC cc ON db.coutwhid = cc.pk_stordoc AND cc.dr = 0
    INNER JOIN BD_INVBASDOC ch ON db.cinvbasid = ch.pk_invbasdoc AND ch.dr = 0
    LEFT JOIN SM_USER us ON zb.coperatorid = us.cuserid
WHERE zb.pk_corp = '1006' AND zb.dr = 0
```

### 模式8：销售结算（应收分析）
```sql
FROM SO_SQUARE ss
    INNER JOIN SO_SQUARE_B sb 
        ON ss.csaleid = sb.csaleid AND sb.dr = 0
        AND IFNULL(sb.blargessflag, 'N') = 'N'
    LEFT JOIN BD_PAYTERM m ON ss.ctermprotocolid = m.pk_payterm
    LEFT JOIN BD_CUMANDOC cum ON ss.ccustomerid = cum.pk_cumandoc
        AND cum.pk_corp = '1006' AND cum.dr = 0
    LEFT JOIN BD_CUBASDOC cub ON cum.pk_cubasdoc = cub.pk_cubasdoc AND cub.dr = 0
    LEFT JOIN BD_PSNDOC psn ON ss.cemployeeid = psn.pk_psndoc AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept ON ss.cdeptid = dept.pk_deptdoc AND dept.dr = 0
WHERE ss.pk_corp = '1006' AND ss.dr = 0
```

---

## 五、易错点与最佳实践

### 5.1 十大易错点

| # | 易错点 | 正确做法 | 影响 |
|---|--------|---------|------|
| 1 | 忘加 `pk_corp = '1006'` | 单据表和管理档案必须加 | 查出其他公司数据 |
| 2 | 忘加 `dr = 0` | 所有表都必须加 | 查出已删除数据 |
| 3 | 基础档案表加了 `pk_corp` | BD_INVBASDOC/BD_CUBASDOC等不需要 | 可能丢失数据 |
| 4 | 客户查询用 BD_CUBASDOC 做主表 | 必须用 BD_CUMANDOC 做主表 | 缺少管理信息 |
| 5 | 存货总账关联只用单字段 | 必须同时匹配 `cinventoryid` 和 `ccalbodyid=crdcenterid` | 成本数据错误 |
| 6 | 信用额度只关联一次 SO_CUCREDIT | 需关联两次（可欠款+临时），且加 `climittypeid` 和 `vcredittypename='2'` | 额度不完整 |
| 7 | 除法无除零保护 | CASE WHEN 分母=0 THEN 0 ELSE ... END | 运行时报错 |
| 8 | 流水公式不统一 | 全局使用同一套"赠品→自定义单价→原币"三级公式 | 不同报表数据不一致 |
| 9 | 地区查询直接JOIN BD_AREACL | 需用子查询先自关联出省市 | 查出错误层级 |
| 10 | termid='01' 直接当天数用 | termid 是字符串，需 `CAST(COALESCE(termid, '0') AS INT)` | 账期计算错误 |

### 5.2 业务特殊规则

| 规则 | 说明 |
|------|------|
| 退货单识别 | `coriginalbillcode LIKE 'TH%'` 或 `LIKE '3U%'` |
| 商桥客户识别 | `cumbase.def3 = '0001C11000000012TJ3X'` |
| 散户标识 | `cumbase.freecustflag` |
| 渠道成员 | `cumbase.isconnflag` |
| 封存判断 | `sealflag IS NOT NULL AND LENGTH(TRIM(sealflag)) > 0` |
| 客商属性 | `custflag`: '0'/'2'=客户，'1'=供应商 |
| 调拨在途超期 | 南京>4天、西安>5天、成都>10天、沈阳>11天 |
| 品类字段映射 | `invpinpai`=品牌，`width`=大类，`length`=品类，`height`=小类 |
| 出入库审批 | `fbillflag >= 3` 表示已审批 |
| 调拨状态 | `fstatusflag`: 1自由/2保存/4审批中/5已审批/7关闭 |

---

## 六、报表开发实战流程示例

以"销售业绩报表"为例，演示完整的六阶段流程：

### Step 1: 需求分析
```
报表名称: 销售业绩报表
分析维度: 时间(日/月/年)、部门、业务员、品牌、品类
核心指标: 销售数量、销售流水、成本、毛利、毛利率
对比分析: 同比增长率、环比增长率
数据来源: SO_SQUAREDETAIL (销售结算明细)
更新频率: 每日
```

### Step 2: 方案设计
```
判断: 涉及6+表关联，多子报表复用 → 需要物化视图
视图层级:
  Layer 1: MV_SALES_DETAIL (明细宽表)
  Layer 2: MV_SALES_DAILY (日汇总), MV_SALES_MONTHLY (月汇总)
报表SQL: 基于三个视图编写9个子查询
```

### Step 3: 视图开发
```
产出:
  - 视图/01_MV_SALES_DETAIL.sql
  - 视图/06_MV_SALES_DAILY.sql
  - 视图/07_MV_SALES_MONTHLY.sql
  - 更新 视图/00_刷新所有视图.sql
```

### Step 4: 报表SQL开发
```
产出:
  - 报表SQL/01_销售业绩报表.sql (MV版，9个子查询)
  - 报表SQL/01_销售业绩报表_原始版本.sql (原始版，2个核心查询)
```

### Step 5: 验证测试
```
1. 执行结构检查清单 → 全部通过
2. 刷新视图后，对比MV版和原始版的月度总额 → 一致
3. 检查边界值（负流水、NULL值） → 无异常
```

### Step 6: 交付上线
```
更新: 报表SQL/README.md, docs/BI报表需求清单.md
状态: 销售业绩报表 ✅ 已完成
```

---

## 附录A：StarRocks 语法备忘

```sql
-- 日期函数
DATE_FORMAT(date, '%Y-%m-%d')     -- 格式化日期
DATE_SUB(date, INTERVAL n MONTH)  -- 日期减
DATE_ADD(date, INTERVAL n DAY)    -- 日期加
DATEDIFF(date1, date2)            -- 日期差
YEAR(date) / MONTH(date)          -- 提取年/月
CURRENT_DATE()                    -- 当前日期
DAYOFWEEK(date)                   -- 星期几

-- 字符串函数
SUBSTR(str, pos, len)             -- 截取子串
LENGTH(TRIM(str))                 -- 去空格后长度
IFNULL(expr, default)             -- 空值替换
COALESCE(v1, v2, ...)             -- 返回第一个非空值
CAST(expr AS INT/DATE)            -- 类型转换

-- 聚合函数
SUM() / COUNT() / COUNT(DISTINCT) / AVG() / MAX() / MIN()
ROUND(expr, n)                    -- 四舍五入

-- 窗口函数
RANK() OVER (PARTITION BY ... ORDER BY ...)
ROW_NUMBER() OVER (...)
SUM(...) OVER ()                  -- 全局汇总（用于占比计算）
```

---

## 附录B：报表需求与视图/SQL对照表

| 编号 | 报表名称 | 优先级 | 依赖视图 | SQL文件 | 状态 |
|------|---------|--------|---------|---------|------|
| 1.1 | 销售业绩报表 | ⭐⭐⭐ | MV_SALES_DETAIL, MV_SALES_MONTHLY | 01_销售业绩报表.sql | ✅ 已完成 |
| 1.2 | 客户价值分析 | ⭐⭐⭐ | MV_SALES_DETAIL, MV_CUSTOMER_MASTER | 02_客户价值分析.sql | ⬜ 待开发 |
| 1.3 | 客户活跃度监控 | ⭐⭐ | MV_CUSTOMER_ACTIVITY | 03_客户活跃度监控.sql | ⬜ 待开发 |
| 1.4 | 新客户开发统计 | ⭐⭐ | MV_CUSTOMER_MASTER | 04_新客户开发统计.sql | ⬜ 待开发 |
| 1.5 | 业务员绩效分析 | ⭐⭐⭐ | MV_SALES_DETAIL, MV_SALES_MONTHLY | 05_业务员绩效分析.sql | ⬜ 待开发 |
| 1.6 | 品类销售分析 | ⭐⭐ | MV_SALES_DETAIL, MV_SALES_MONTHLY | 06_品类销售分析.sql | ⬜ 待开发 |
| 2.1 | 库存监控看板 | ⭐⭐⭐ | MV_INVENTORY_SNAPSHOT | 07_库存监控看板.sql | ⬜ 待开发 |
| 2.2 | 库存周转分析 | ⭐⭐⭐ | MV_INVENTORY_SNAPSHOT, MV_SALES_DETAIL | 08_库存周转分析.sql | ⬜ 待开发 |
| 2.3 | 出入库统计 | ⭐⭐ | (直接查原始表) | 09_出入库统计.sql | ⬜ 待开发 |
| 2.4 | 调拨在途监控 | ⭐⭐ | (直接查原始表) | 10_调拨在途监控.sql | ⬜ 待开发 |
| 3.1 | 应收账龄分析 | ⭐⭐⭐ | MV_RECEIVABLE_SUMMARY | 11_应收账龄分析.sql | ⬜ 待开发 |
| 3.2 | 客户信用管理 | ⭐⭐⭐ | MV_CUSTOMER_MASTER | 12_客户信用管理.sql | ⬜ 待开发 |
| 3.3 | 毛利分析 | ⭐⭐⭐ | MV_SALES_DETAIL, MV_SALES_MONTHLY | 13_毛利分析.sql | ⬜ 待开发 |
| 3.4 | 经营日报 | ⭐⭐⭐ | MV_SALES_DAILY, MV_INVENTORY_SNAPSHOT | 14_经营日报.sql | ⬜ 待开发 |
| 4.1 | 采购业绩统计 | ⭐⭐ | (直接查原始表) | 15_采购业绩统计.sql | ⬜ 待开发 |
| 4.2 | 供应商绩效评估 | ⭐⭐ | (直接查原始表) | 16_供应商绩效评估.sql | ⬜ 待开发 |
| 4.3 | 采购在途监控 | ⭐⭐ | (直接查原始表) | 17_采购在途监控.sql | ⬜ 待开发 |
| 5.1 | 电商业务监控 | ⭐⭐ | MV_SALES_DETAIL | 18_电商业务监控.sql | ⬜ 待开发 |
| 5.2 | 放货业务管理 | ⭐⭐ | (直接查原始表) | 19_放货业务管理.sql | ⬜ 待开发 |
| 5.3 | 退货分析 | ⭐⭐ | MV_SALES_DETAIL | 20_退货分析.sql | ⬜ 待开发 |

---

**文档版本**: v1.0  
**创建日期**: 2026-03-03  
**适用系统**: 用友NC + StarRocks 数据仓库  
**维护说明**: 每完成一个报表后更新附录B的状态

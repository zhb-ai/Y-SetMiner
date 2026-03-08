# 用友NC数据仓库 BI报表项目

基于 StarRocks 数据仓库，从用友NC ERP系统提取数据，生成各类BI报表SQL。

---

## 项目结构

```
starrocks_ai/
│
├── docs/                           📚 文档中心
│   ├── 数据字典.md                  表结构与字段定义
│   ├── 数据库表关系图.md            表关系、主外键、关联模式速查
│   ├── SQL编码规范.md               SQL编码规则速查手册
│   ├── 业务场景SQL模板.md           5大业务场景完整SQL模板 + 日期/聚合/特殊字段技巧
│   ├── StarRocks语法参考.md         数据类型/函数/SQL语法/窗口函数/常见陷阱
│   ├── SQL开发全流程规范.md         从需求到SQL的六阶段标准流程
│   ├── 物化视图设计.md              物化视图架构设计（基于StarRocks 3.5）
│   ├── BI报表需求清单.md            20个报表需求全量清单
│   └── SQL案例参考.md               历史SQL案例汇总说明
│
├── 视图SQL/                           🗃️ 物化视图DDL
│   ├── 00_刷新所有视图.sql          手动刷新脚本
│   ├── 01_MV_SALES_DETAIL.sql      销售明细宽表
│   ├── 02_MV_INVENTORY_SNAPSHOT.sql 库存快照表
│   ├── 03_MV_RECEIVABLE_SUMMARY.sql 应收账款汇总表
│   ├── 04_MV_CUSTOMER_MASTER.sql   客户主数据视图
│   ├── 05_MV_PRODUCT_MASTER.sql    商品主数据视图
│   ├── 06_MV_SALES_DAILY.sql       销售日汇总表
│   ├── 07_MV_SALES_MONTHLY.sql     销售月汇总表
│   └── 08_MV_CUSTOMER_ACTIVITY.sql 客户活跃度统计
│
├── 报表SQL/                        📊 报表查询SQL（正式产出）
│   ├── README.md                    使用说明
│   ├── 01_销售业绩报表.sql          物化视图版本（推荐）
│   └── 01_销售业绩报表_原始版本.sql  原始表版本（对数验证）
│
├── 案例/                           📁 历史SQL案例（参考资料）
│   └── *.sql                        ~170个业务SQL案例
│
└── .cursor/rules/                  🤖 AI辅助开发规则
    └── sql-development.mdc         Cursor自动加载的SQL开发规范
```

## 快速入门

### 1. 了解规范
阅读顺序：`docs/SQL编码规范.md` → `docs/业务场景SQL模板.md` → `docs/数据库表关系图.md` → `docs/数据字典.md`

### 2. 开发新报表
按照 `docs/SQL开发全流程规范.md` 的六阶段流程执行：
```
需求分析 → 方案设计 → 视图开发 → 报表SQL开发 → 验证测试 → 交付上线
```

### 3. 创建/刷新物化视图
参考 `docs/物化视图设计.md` 中的DDL规范和刷新策略。

### 4. AI辅助开发
使用 Cursor IDE 打开项目，`.cursor/rules/sql-development.mdc` 会自动加载，AI生成SQL时自动遵循编码规范。

## 关键规则速记

- `pk_corp = '1006'`：单据表和管理档案表必须加
- `dr = 0`：所有表都必须加
- 基础档案表（BD_INVBASDOC等）不加 pk_corp
- 客户查询用 BD_CUMANDOC 做主表（不是BD_CUBASDOC）
- 销售流水统一公式：赠品→0、自定义单价→vbodydef5、否则→noriginalcurmny
- 金额用 `ROUND(..., 2)`，除法有除零保护

## 报表进度

| 完成 | 报表 |
|------|------|
| ✅ | 销售业绩报表 |
| ⬜ | 其余19个报表（详见 docs/BI报表需求清单.md） |

---

**数据库**: StarRocks 3.5  
**源系统**: 用友NC ERP  
**更新日期**: 2026-03-03

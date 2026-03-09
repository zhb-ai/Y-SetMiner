-- =====================================================
-- 报表14: 经营日报
-- 业务价值: 全面掌握经营状况，快速决策
-- MV依赖: MV_SALES_DAILY + MV_INVENTORY_SNAPSHOT + MV_RECEIVABLE_SUMMARY
-- 更新频率: 每日
-- =====================================================

-- =====================================================
-- 14.1 经营日报综合看板
-- =====================================================

-- 销售板块
SELECT '销售' AS 板块, 指标名称, 指标值 FROM (
    SELECT
        '当日销售流水' AS 指标名称,
        ROUND(SUM(销售流水), 2) AS 指标值
    FROM MV_SALES_DAILY
    WHERE 日期 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m-%d')

    UNION ALL

    SELECT
        '当日毛利' AS 指标名称,
        ROUND(SUM(毛利), 2) AS 指标值
    FROM MV_SALES_DAILY
    WHERE 日期 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m-%d')

    UNION ALL

    SELECT
        '当月累计销售流水' AS 指标名称,
        ROUND(SUM(销售流水), 2) AS 指标值
    FROM MV_SALES_DAILY
    WHERE 日期 >= DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')

    UNION ALL

    SELECT
        '当月累计毛利' AS 指标名称,
        ROUND(SUM(毛利), 2) AS 指标值
    FROM MV_SALES_DAILY
    WHERE 日期 >= DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')
) t

UNION ALL

-- 库存板块
SELECT '库存' AS 板块, '库存总金额' AS 指标名称,
    ROUND(SUM(库存金额), 2) AS 指标值
FROM MV_INVENTORY_SNAPSHOT

UNION ALL

-- 应收板块
SELECT '应收' AS 板块, '未结算应收总额' AS 指标名称,
    ROUND(SUM(未结算金额), 2) AS 指标值
FROM MV_RECEIVABLE_SUMMARY
WHERE 未结算金额 > 0;


-- =====================================================
-- 14.2 部门销售日报
-- =====================================================
SELECT
    日期,
    大部门名称,
    部门名称,
    SUM(客户数) AS 客户数,
    SUM(订单数) AS 订单数,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率
FROM MV_SALES_DAILY
WHERE 日期 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m-%d')
GROUP BY 日期, 大部门名称, 部门名称
ORDER BY 销售流水 DESC;


-- =====================================================
-- 14.3 日环比分析 (今天 vs 昨天)
-- =====================================================
WITH 今日 AS (
    SELECT
        部门名称,
        ROUND(SUM(销售流水), 2) AS 今日流水,
        ROUND(SUM(毛利), 2) AS 今日毛利
    FROM MV_SALES_DAILY
    WHERE 日期 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m-%d')
    GROUP BY 部门名称
),
昨日 AS (
    SELECT
        部门名称,
        ROUND(SUM(销售流水), 2) AS 昨日流水,
        ROUND(SUM(毛利), 2) AS 昨日毛利
    FROM MV_SALES_DAILY
    WHERE 日期 = DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY), '%Y-%m-%d')
    GROUP BY 部门名称
)
SELECT
    COALESCE(今日.部门名称, 昨日.部门名称) AS 部门名称,
    COALESCE(今日.今日流水, 0) AS 今日流水,
    COALESCE(昨日.昨日流水, 0) AS 昨日流水,
    ROUND(
        (COALESCE(今日.今日流水, 0) - COALESCE(昨日.昨日流水, 0))
        / NULLIF(昨日.昨日流水, 0) * 100, 2
    ) AS 流水环比,
    COALESCE(今日.今日毛利, 0) AS 今日毛利,
    COALESCE(昨日.昨日毛利, 0) AS 昨日毛利
FROM 今日
FULL OUTER JOIN 昨日 ON 今日.部门名称 = 昨日.部门名称
ORDER BY 今日流水 DESC;


-- =====================================================
-- 14.4 月累计同比 (本年 vs 去年同期截至今日)
-- =====================================================
WITH 本年 AS (
    SELECT
        部门名称,
        ROUND(SUM(销售流水), 2) AS 本年累计流水,
        ROUND(SUM(毛利), 2) AS 本年累计毛利
    FROM MV_SALES_DAILY
    WHERE 日期 >= CONCAT(YEAR(CURRENT_DATE()), '-01-01')
    GROUP BY 部门名称
),
去年 AS (
    SELECT
        部门名称,
        ROUND(SUM(销售流水), 2) AS 去年同期流水,
        ROUND(SUM(毛利), 2) AS 去年同期毛利
    FROM MV_SALES_DAILY
    WHERE 日期 >= CONCAT(YEAR(CURRENT_DATE()) - 1, '-01-01')
        AND 日期 <= DATE_FORMAT(
            DATE_SUB(CURRENT_DATE(), INTERVAL 1 YEAR), '%Y-%m-%d'
        )
    GROUP BY 部门名称
)
SELECT
    COALESCE(本年.部门名称, 去年.部门名称) AS 部门名称,
    COALESCE(本年.本年累计流水, 0) AS 本年累计流水,
    COALESCE(去年.去年同期流水, 0) AS 去年同期流水,
    ROUND(
        (COALESCE(本年.本年累计流水, 0) - COALESCE(去年.去年同期流水, 0))
        / NULLIF(去年.去年同期流水, 0) * 100, 2
    ) AS 流水同比增长率
FROM 本年
FULL OUTER JOIN 去年 ON 本年.部门名称 = 去年.部门名称
ORDER BY 本年累计流水 DESC;


-- =====================================================
-- 14.5 近7天销售趋势
-- =====================================================
SELECT
    日期,
    SUM(客户数) AS 客户数,
    SUM(订单数) AS 订单数,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率
FROM MV_SALES_DAILY
WHERE 日期 >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), '%Y-%m-%d')
GROUP BY 日期
ORDER BY 日期;

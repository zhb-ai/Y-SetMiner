-- =====================================================
-- 报表5: 业务员绩效分析
-- 业务价值: 评估业务员表现，优化激励机制
-- MV依赖: MV_SALES_DETAIL, MV_CUSTOMER_MASTER, MV_SALES_MONTHLY
-- 更新频率: 每月
-- =====================================================

-- =====================================================
-- 5.1 业务员月度绩效汇总
-- =====================================================
SELECT
    年月,
    部门名称,
    大部门名称,
    业务员姓名,
    客户数,
    订单数,
    SUM(销售数量) AS 销售数量,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(销售成本), 2) AS 销售成本,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率
FROM MV_SALES_MONTHLY
WHERE 年月 >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m')
GROUP BY 年月, 部门名称, 大部门名称, 业务员姓名, 客户数, 订单数
ORDER BY 年月 DESC, 销售流水 DESC;


-- =====================================================
-- 5.2 业务员本月业绩排名
-- =====================================================
SELECT
    业务员姓名,
    部门名称,
    COUNT(DISTINCT 客户主键) AS 成交客户数,
    COUNT(DISTINCT 销售结算主键) AS 订单数,
    ROUND(SUM(销售流水), 2) AS 本月销售流水,
    ROUND(SUM(毛利), 2) AS 本月毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率,
    RANK() OVER (ORDER BY SUM(销售流水) DESC) AS 全公司排名,
    RANK() OVER (PARTITION BY 部门名称 ORDER BY SUM(销售流水) DESC) AS 部门内排名
FROM MV_SALES_DETAIL
WHERE 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m')
    AND 是否赠品 = 'N'
GROUP BY 业务员姓名, 部门名称
ORDER BY 本月销售流水 DESC;


-- =====================================================
-- 5.3 业务员客户管理能力分析
-- =====================================================
WITH 销售统计 AS (
    SELECT
        业务员姓名,
        部门名称,
        COUNT(DISTINCT 客户主键) AS 成交客户数,
        ROUND(SUM(销售流水), 2) AS 销售流水,
        ROUND(SUM(毛利), 2) AS 毛利
    FROM MV_SALES_DETAIL
    WHERE 年度 = YEAR(CURRENT_DATE())
        AND 是否赠品 = 'N'
    GROUP BY 业务员姓名, 部门名称
),
客户管理 AS (
    SELECT
        业务员姓名,
        部门名称,
        COUNT(*) AS 管理客户总数,
        SUM(CASE WHEN 是否封存 = 'N' THEN 1 ELSE 0 END) AS 有效客户数
    FROM MV_CUSTOMER_MASTER
    GROUP BY 业务员姓名, 部门名称
)
SELECT
    COALESCE(s.业务员姓名, c.业务员姓名) AS 业务员姓名,
    COALESCE(s.部门名称, c.部门名称) AS 部门名称,
    COALESCE(c.管理客户总数, 0) AS 管理客户总数,
    COALESCE(c.有效客户数, 0) AS 有效客户数,
    COALESCE(s.成交客户数, 0) AS 本年成交客户数,
    ROUND(COALESCE(s.成交客户数, 0) * 100.0 / NULLIF(c.有效客户数, 0), 2) AS 客户激活率,
    COALESCE(s.销售流水, 0) AS 本年销售流水,
    COALESCE(s.毛利, 0) AS 本年毛利,
    ROUND(COALESCE(s.销售流水, 0) / NULLIF(COALESCE(s.成交客户数, 0), 0), 2) AS 客均销售额
FROM 销售统计 s
FULL OUTER JOIN 客户管理 c
    ON s.业务员姓名 = c.业务员姓名
    AND s.部门名称 = c.部门名称
ORDER BY 本年销售流水 DESC;


-- =====================================================
-- 5.4 业务员同比增长排名
-- =====================================================
WITH 本年 AS (
    SELECT
        业务员姓名,
        部门名称,
        ROUND(SUM(销售流水), 2) AS 本年流水,
        ROUND(SUM(毛利), 2) AS 本年毛利
    FROM MV_SALES_MONTHLY
    WHERE 年度 = YEAR(CURRENT_DATE())
        AND 月份 <= MONTH(CURRENT_DATE())
    GROUP BY 业务员姓名, 部门名称
),
去年 AS (
    SELECT
        业务员姓名,
        部门名称,
        ROUND(SUM(销售流水), 2) AS 去年流水,
        ROUND(SUM(毛利), 2) AS 去年毛利
    FROM MV_SALES_MONTHLY
    WHERE 年度 = YEAR(CURRENT_DATE()) - 1
        AND 月份 <= MONTH(CURRENT_DATE())
    GROUP BY 业务员姓名, 部门名称
)
SELECT
    COALESCE(本年.业务员姓名, 去年.业务员姓名) AS 业务员姓名,
    COALESCE(本年.部门名称, 去年.部门名称) AS 部门名称,
    COALESCE(本年.本年流水, 0) AS 本年累计流水,
    COALESCE(去年.去年流水, 0) AS 去年同期流水,
    ROUND(
        (COALESCE(本年.本年流水, 0) - COALESCE(去年.去年流水, 0))
        / NULLIF(去年.去年流水, 0) * 100, 2
    ) AS 流水同比增长率,
    COALESCE(本年.本年毛利, 0) AS 本年累计毛利,
    COALESCE(去年.去年毛利, 0) AS 去年同期毛利,
    ROUND(
        (COALESCE(本年.本年毛利, 0) - COALESCE(去年.去年毛利, 0))
        / NULLIF(去年.去年毛利, 0) * 100, 2
    ) AS 毛利同比增长率
FROM 本年
FULL OUTER JOIN 去年
    ON 本年.业务员姓名 = 去年.业务员姓名
    AND 本年.部门名称 = 去年.部门名称
ORDER BY 流水同比增长率 DESC;

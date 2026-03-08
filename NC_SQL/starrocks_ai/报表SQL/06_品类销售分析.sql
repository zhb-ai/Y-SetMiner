-- =====================================================
-- 报表6: 品类销售分析
-- 业务价值: 优化产品组合，聚焦优势品类
-- MV依赖: MV_SALES_DETAIL, MV_SALES_MONTHLY
-- 更新频率: 每月
-- =====================================================

-- =====================================================
-- 6.1 品类销售汇总 (本月/本年)
-- =====================================================
SELECT
    品牌,
    大类,
    品类,
    ROUND(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END), 2) AS 本月销售流水,
    ROUND(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 毛利 ELSE 0 END), 2) AS 本月毛利,
    ROUND(
        SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 毛利 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END), 0) * 100, 2
    ) AS 本月毛利率,
    ROUND(SUM(CASE WHEN 年度 = YEAR(CURRENT_DATE()) THEN 销售流水 ELSE 0 END), 2) AS 本年累计流水,
    ROUND(SUM(CASE WHEN 年度 = YEAR(CURRENT_DATE()) THEN 毛利 ELSE 0 END), 2) AS 本年累计毛利,
    ROUND(
        SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END)
        / NULLIF(SUM(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END)) OVER (), 0) * 100, 2
    ) AS 本月占比
FROM MV_SALES_MONTHLY
GROUP BY 品牌, 大类, 品类
ORDER BY 本月销售流水 DESC;


-- =====================================================
-- 6.2 ABC分类 (品类级别)
-- =====================================================
WITH 品类汇总 AS (
    SELECT
        品牌,
        大类,
        品类,
        ROUND(SUM(销售流水), 2) AS 销售流水,
        ROUND(SUM(毛利), 2) AS 毛利,
        SUM(销售数量) AS 销售数量
    FROM MV_SALES_DETAIL
    WHERE 年度 = YEAR(CURRENT_DATE())
        AND 是否赠品 = 'N'
    GROUP BY 品牌, 大类, 品类
),
排名 AS (
    SELECT
        品牌, 大类, 品类, 销售流水, 毛利, 销售数量,
        SUM(销售流水) OVER (ORDER BY 销售流水 DESC) AS 累计流水,
        SUM(销售流水) OVER () AS 总流水
    FROM 品类汇总
)
SELECT
    品牌, 大类, 品类,
    销售流水,
    毛利,
    ROUND(毛利 / NULLIF(销售流水, 0) * 100, 2) AS 毛利率,
    销售数量,
    ROUND(销售流水 / NULLIF(总流水, 0) * 100, 2) AS 占比,
    ROUND(累计流水 / NULLIF(总流水, 0) * 100, 2) AS 累计占比,
    CASE
        WHEN 累计流水 / NULLIF(总流水, 0) <= 0.80 THEN 'A类'
        WHEN 累计流水 / NULLIF(总流水, 0) <= 0.95 THEN 'B类'
        ELSE 'C类'
    END AS ABC分类
FROM 排名
ORDER BY 销售流水 DESC;


-- =====================================================
-- 6.3 品类月度趋势 (近12个月)
-- =====================================================
SELECT
    年月,
    大类,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率,
    SUM(销售数量) AS 销售数量
FROM MV_SALES_MONTHLY
WHERE 年月 >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m')
GROUP BY 年月, 大类
ORDER BY 年月, 大类;


-- =====================================================
-- 6.4 品类同比增长分析
-- =====================================================
WITH 本年 AS (
    SELECT 大类, 品牌, ROUND(SUM(销售流水), 2) AS 本年流水
    FROM MV_SALES_MONTHLY
    WHERE 年度 = YEAR(CURRENT_DATE()) AND 月份 <= MONTH(CURRENT_DATE())
    GROUP BY 大类, 品牌
),
去年 AS (
    SELECT 大类, 品牌, ROUND(SUM(销售流水), 2) AS 去年流水
    FROM MV_SALES_MONTHLY
    WHERE 年度 = YEAR(CURRENT_DATE()) - 1 AND 月份 <= MONTH(CURRENT_DATE())
    GROUP BY 大类, 品牌
)
SELECT
    COALESCE(本年.大类, 去年.大类) AS 大类,
    COALESCE(本年.品牌, 去年.品牌) AS 品牌,
    COALESCE(本年.本年流水, 0) AS 本年累计流水,
    COALESCE(去年.去年流水, 0) AS 去年同期流水,
    ROUND(
        (COALESCE(本年.本年流水, 0) - COALESCE(去年.去年流水, 0))
        / NULLIF(去年.去年流水, 0) * 100, 2
    ) AS 同比增长率
FROM 本年
FULL OUTER JOIN 去年 ON 本年.大类 = 去年.大类 AND 本年.品牌 = 去年.品牌
ORDER BY 同比增长率 DESC;

-- =====================================================
-- 报表2: 客户价值分析
-- 业务价值: 识别核心客户，优化客户结构
-- MV依赖: MV_SALES_DETAIL, MV_CUSTOMER_MASTER
-- 更新频率: 每月
-- =====================================================

-- =====================================================
-- 2.1 客户销售汇总 (TOP N)
-- =====================================================
SELECT
    客户编码,
    客户名称,
    部门名称,
    业务员姓名,
    省份,
    城市,
    是否商桥,
    COUNT(DISTINCT 销售结算主键) AS 订单数,
    SUM(销售数量) AS 销售数量,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(销售成本), 2) AS 销售成本,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率
FROM MV_SALES_DETAIL
WHERE 年月 >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m')
    AND 是否赠品 = 'N'
GROUP BY 客户编码, 客户名称, 部门名称, 业务员姓名, 省份, 城市, 是否商桥
ORDER BY 销售流水 DESC
LIMIT 100;


-- =====================================================
-- 2.2 客户贡献度与ABC分类
-- =====================================================
WITH 客户汇总 AS (
    SELECT
        客户编码,
        客户名称,
        部门名称,
        业务员姓名,
        ROUND(SUM(销售流水), 2) AS 销售流水,
        ROUND(SUM(毛利), 2) AS 毛利
    FROM MV_SALES_DETAIL
    WHERE 年度 = YEAR(CURRENT_DATE())
        AND 是否赠品 = 'N'
    GROUP BY 客户编码, 客户名称, 部门名称, 业务员姓名
),
排名 AS (
    SELECT
        客户编码,
        客户名称,
        部门名称,
        业务员姓名,
        销售流水,
        毛利,
        ROUND(销售流水 / NULLIF(SUM(销售流水) OVER (), 0) * 100, 2) AS 贡献度,
        SUM(销售流水) OVER (ORDER BY 销售流水 DESC) AS 累计销售流水,
        SUM(销售流水) OVER () AS 总销售流水,
        ROW_NUMBER() OVER (ORDER BY 销售流水 DESC) AS 排名
    FROM 客户汇总
)
SELECT
    排名,
    客户编码,
    客户名称,
    部门名称,
    业务员姓名,
    销售流水,
    毛利,
    贡献度,
    ROUND(累计销售流水 / NULLIF(总销售流水, 0) * 100, 2) AS 累计占比,
    CASE
        WHEN 累计销售流水 / NULLIF(总销售流水, 0) <= 0.80 THEN 'A类'
        WHEN 累计销售流水 / NULLIF(总销售流水, 0) <= 0.95 THEN 'B类'
        ELSE 'C类'
    END AS ABC分类
FROM 排名
ORDER BY 排名;


-- =====================================================
-- 2.3 客户品类偏好分析
-- =====================================================
SELECT
    客户名称,
    品牌,
    大类,
    品类,
    COUNT(DISTINCT 销售结算主键) AS 订单数,
    SUM(销售数量) AS 销售数量,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(销售流水) / NULLIF(SUM(SUM(销售流水)) OVER (PARTITION BY 客户名称), 0) * 100, 2) AS 品类占比
FROM MV_SALES_DETAIL
WHERE 年月 >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH), '%Y-%m')
    AND 是否赠品 = 'N'
GROUP BY 客户名称, 品牌, 大类, 品类
ORDER BY 客户名称, 销售流水 DESC;


-- =====================================================
-- 2.4 客户地区分布
-- =====================================================
SELECT
    省份,
    城市,
    COUNT(DISTINCT 客户主键) AS 客户数,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率,
    ROUND(SUM(销售流水) / NULLIF(SUM(SUM(销售流水)) OVER (), 0) * 100, 2) AS 区域占比
FROM MV_SALES_DETAIL
WHERE 年度 = YEAR(CURRENT_DATE())
    AND 是否赠品 = 'N'
GROUP BY 省份, 城市
ORDER BY 销售流水 DESC;


-- =====================================================
-- 2.5 客户集中度分析 (CR5/CR10/CR20)
-- =====================================================
WITH 客户排名 AS (
    SELECT
        客户名称,
        ROUND(SUM(销售流水), 2) AS 销售流水,
        ROW_NUMBER() OVER (ORDER BY SUM(销售流水) DESC) AS 排名
    FROM MV_SALES_DETAIL
    WHERE 年度 = YEAR(CURRENT_DATE())
        AND 是否赠品 = 'N'
    GROUP BY 客户名称
)
SELECT
    ROUND(SUM(CASE WHEN 排名 <= 5 THEN 销售流水 ELSE 0 END) / NULLIF(SUM(销售流水), 0) * 100, 2) AS CR5,
    ROUND(SUM(CASE WHEN 排名 <= 10 THEN 销售流水 ELSE 0 END) / NULLIF(SUM(销售流水), 0) * 100, 2) AS CR10,
    ROUND(SUM(CASE WHEN 排名 <= 20 THEN 销售流水 ELSE 0 END) / NULLIF(SUM(销售流水), 0) * 100, 2) AS CR20,
    COUNT(*) AS 总客户数
FROM 客户排名;

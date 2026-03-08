-- =====================================================
-- 报表4: 新客户开发统计
-- 业务价值: 评估市场拓展效果
-- MV依赖: MV_CUSTOMER_MASTER (创建日期), MV_SALES_DETAIL (销售数据)
-- 更新频率: 每月
-- 说明: 新客户定义为统计周期内在NC系统中创建的客户（基于 createtime 字段）
-- =====================================================

-- =====================================================
-- 4.1 新客户月度统计
-- =====================================================
SELECT
    DATE_FORMAT(cm.创建日期, '%Y-%m') AS 月份,
    COUNT(DISTINCT cm.客户主键) AS 新客户数,
    COUNT(DISTINCT sd.客户主键) AS 有成交客户数,
    ROUND(SUM(sd.销售流水), 2) AS 新客销售流水,
    ROUND(SUM(sd.毛利), 2) AS 新客毛利
FROM MV_CUSTOMER_MASTER cm
LEFT JOIN MV_SALES_DETAIL sd
    ON cm.客户主键 = sd.客户主键
    AND sd.是否赠品 = 'N'
    AND sd.年月 = DATE_FORMAT(cm.创建日期, '%Y-%m')
WHERE cm.创建日期 >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m-01')
    AND cm.是否封存 = 'N'
GROUP BY DATE_FORMAT(cm.创建日期, '%Y-%m')
ORDER BY 月份 DESC;


-- =====================================================
-- 4.2 业务员新客开发排名 (本年)
-- =====================================================
SELECT
    cm.业务员姓名,
    cm.部门名称,
    COUNT(DISTINCT cm.客户主键) AS 新客户数,
    COUNT(DISTINCT sd.客户主键) AS 有成交客户数,
    ROUND(SUM(sd.销售流水), 2) AS 新客销售流水,
    ROUND(SUM(sd.毛利), 2) AS 新客毛利,
    RANK() OVER (ORDER BY COUNT(DISTINCT cm.客户主键) DESC) AS 排名
FROM MV_CUSTOMER_MASTER cm
LEFT JOIN MV_SALES_DETAIL sd
    ON cm.客户主键 = sd.客户主键
    AND sd.是否赠品 = 'N'
    AND sd.年度 = YEAR(CURRENT_DATE())
WHERE cm.创建日期 >= CONCAT(YEAR(CURRENT_DATE()), '-01-01')
    AND cm.是否封存 = 'N'
GROUP BY cm.业务员姓名, cm.部门名称
ORDER BY 新客户数 DESC;


-- =====================================================
-- 4.3 新客户销售贡献分析 (本年新客 vs 老客)
-- =====================================================
WITH 新客 AS (
    SELECT DISTINCT 客户主键
    FROM MV_CUSTOMER_MASTER
    WHERE 创建日期 >= CONCAT(YEAR(CURRENT_DATE()), '-01-01')
)
SELECT
    CASE WHEN n.客户主键 IS NOT NULL THEN '新客户' ELSE '老客户' END AS 客户类型,
    COUNT(DISTINCT sd.客户主键) AS 客户数,
    ROUND(SUM(sd.销售流水), 2) AS 销售流水,
    ROUND(SUM(sd.毛利), 2) AS 毛利,
    ROUND(SUM(sd.销售流水) / NULLIF(SUM(SUM(sd.销售流水)) OVER (), 0) * 100, 2) AS 销售占比
FROM MV_SALES_DETAIL sd
LEFT JOIN 新客 n ON sd.客户主键 = n.客户主键
WHERE sd.年度 = YEAR(CURRENT_DATE())
    AND sd.是否赠品 = 'N'
GROUP BY CASE WHEN n.客户主键 IS NOT NULL THEN '新客户' ELSE '老客户' END;


-- =====================================================
-- 4.4 新客户地区分布 (本年)
-- =====================================================
SELECT
    cm.省份,
    cm.城市,
    COUNT(DISTINCT cm.客户主键) AS 新客户数,
    ROUND(SUM(sd.销售流水), 2) AS 新客销售流水
FROM MV_CUSTOMER_MASTER cm
LEFT JOIN MV_SALES_DETAIL sd
    ON cm.客户主键 = sd.客户主键
    AND sd.是否赠品 = 'N'
    AND sd.年度 = YEAR(CURRENT_DATE())
WHERE cm.创建日期 >= CONCAT(YEAR(CURRENT_DATE()), '-01-01')
    AND cm.是否封存 = 'N'
GROUP BY cm.省份, cm.城市
ORDER BY 新客户数 DESC;

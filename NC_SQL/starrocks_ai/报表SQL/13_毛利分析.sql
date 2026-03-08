-- =====================================================
-- 报表13: 毛利分析
-- 业务价值: 评估产品盈利能力，优化产品结构
-- MV依赖: MV_SALES_DETAIL
-- 更新频率: 每月
-- 与报表01的区别: 本报表侧重商品维度的盈利能力分析，可下钻到单品级别
-- =====================================================

-- =====================================================
-- 13.1 品类毛利汇总 (本月)
-- =====================================================
SELECT
    品牌,
    大类,
    品类,
    SUM(销售数量) AS 销售数量,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(销售成本), 2) AS 销售成本,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率,
    ROUND(SUM(毛利) / NULLIF(SUM(SUM(毛利)) OVER (), 0) * 100, 2) AS 毛利贡献度
FROM MV_SALES_DETAIL
WHERE 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m')
    AND 是否赠品 = 'N'
GROUP BY 品牌, 大类, 品类
ORDER BY 毛利 DESC;


-- =====================================================
-- 13.2 高毛利商品 TOP 30 (本年)
-- =====================================================
SELECT
    商品编码,
    商品名称,
    品牌,
    大类,
    规格,
    SUM(销售数量) AS 销售数量,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率,
    ROW_NUMBER() OVER (ORDER BY SUM(毛利) DESC) AS 排名
FROM MV_SALES_DETAIL
WHERE 年度 = YEAR(CURRENT_DATE())
    AND 是否赠品 = 'N'
GROUP BY 商品编码, 商品名称, 品牌, 大类, 规格
HAVING SUM(销售流水) > 0
ORDER BY 毛利 DESC
LIMIT 30;


-- =====================================================
-- 13.3 低毛利/负毛利商品预警
-- =====================================================
SELECT
    商品编码,
    商品名称,
    品牌,
    大类,
    SUM(销售数量) AS 销售数量,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(销售成本), 2) AS 销售成本,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率
FROM MV_SALES_DETAIL
WHERE 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m')
    AND 是否赠品 = 'N'
GROUP BY 商品编码, 商品名称, 品牌, 大类
HAVING SUM(毛利) < 0 OR SUM(毛利) / NULLIF(SUM(销售流水), 0) < 0.05
ORDER BY 毛利率;


-- =====================================================
-- 13.4 毛利月度趋势
-- =====================================================
SELECT
    年月,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(销售成本), 2) AS 销售成本,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率,
    ROUND(SUM(CASE WHEN 大类 = '原装' THEN 毛利 ELSE 0 END), 2) AS 原装毛利,
    ROUND(SUM(CASE WHEN 大类 = '兼容' THEN 毛利 ELSE 0 END), 2) AS 兼容毛利,
    ROUND(SUM(CASE WHEN 大类 = '打印机' THEN 毛利 ELSE 0 END), 2) AS 打印机毛利
FROM MV_SALES_DETAIL
WHERE 年月 >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m')
    AND 是否赠品 = 'N'
GROUP BY 年月
ORDER BY 年月;


-- =====================================================
-- 13.5 部门毛利对比
-- =====================================================
SELECT
    大部门名称,
    部门名称,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(毛利), 2) AS 毛利,
    ROUND(SUM(毛利) / NULLIF(SUM(销售流水), 0) * 100, 2) AS 毛利率,
    RANK() OVER (ORDER BY SUM(毛利) / NULLIF(SUM(销售流水), 0) DESC) AS 毛利率排名
FROM MV_SALES_DETAIL
WHERE 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m')
    AND 是否赠品 = 'N'
GROUP BY 大部门名称, 部门名称
ORDER BY 毛利率 DESC;

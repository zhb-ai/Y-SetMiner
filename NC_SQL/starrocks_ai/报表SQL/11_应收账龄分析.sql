-- =====================================================
-- 报表11: 应收账龄分析
-- 业务价值: 加强资金管理，降低坏账风险
-- MV依赖: MV_RECEIVABLE_SUMMARY
-- 更新频率: 每日
-- 说明: 超期天数在查询层通过 DATEDIFF(CURRENT_DATE(), 预计结算日期) 实时计算
-- =====================================================

-- =====================================================
-- 11.1 应收账龄分布 (汇总)
-- =====================================================
SELECT
    CASE
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 0 THEN '未到期'
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 3 THEN '1-3天'
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 10 THEN '4-10天'
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 30 THEN '11-30天'
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 90 THEN '31-90天'
        ELSE '90天以上'
    END AS 账龄分类,
    COUNT(DISTINCT 客户主键) AS 客户数,
    COUNT(DISTINCT 结算单主键) AS 单据数,
    ROUND(SUM(应收金额), 2) AS 应收金额,
    ROUND(SUM(未结算金额), 2) AS 未结算金额
FROM MV_RECEIVABLE_SUMMARY
WHERE 未结算金额 > 0
GROUP BY
    CASE
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 0 THEN '未到期'
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 3 THEN '1-3天'
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 10 THEN '4-10天'
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 30 THEN '11-30天'
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 90 THEN '31-90天'
        ELSE '90天以上'
    END
ORDER BY
    CASE
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 0 THEN 1
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 3 THEN 2
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 10 THEN 3
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 30 THEN 4
        WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 90 THEN 5
        ELSE 6
    END;


-- =====================================================
-- 11.2 客户应收明细
-- =====================================================
SELECT
    客户编码,
    客户名称,
    部门名称,
    业务员姓名,
    COUNT(DISTINCT 结算单主键) AS 单据数,
    ROUND(SUM(应收金额), 2) AS 应收总额,
    ROUND(SUM(未结算金额), 2) AS 未结算总额,
    ROUND(SUM(CASE WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) <= 0 THEN 未结算金额 ELSE 0 END), 2) AS 未到期,
    ROUND(SUM(CASE WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) BETWEEN 1 AND 30 THEN 未结算金额 ELSE 0 END), 2) AS 超期1_30天,
    ROUND(SUM(CASE WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) BETWEEN 31 AND 90 THEN 未结算金额 ELSE 0 END), 2) AS 超期31_90天,
    ROUND(SUM(CASE WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) > 90 THEN 未结算金额 ELSE 0 END), 2) AS 超期90天以上,
    MAX(DATEDIFF(CURRENT_DATE(), 预计结算日期)) AS 最长超期天数
FROM MV_RECEIVABLE_SUMMARY
WHERE 未结算金额 > 0
GROUP BY 客户编码, 客户名称, 部门名称, 业务员姓名
ORDER BY 未结算总额 DESC;


-- =====================================================
-- 11.3 超期客户预警 (超期且未结算)
-- =====================================================
SELECT
    客户编码,
    客户名称,
    业务员姓名,
    部门名称,
    结算单号,
    单据日期,
    账期天数,
    预计结算日期,
    DATEDIFF(CURRENT_DATE(), 预计结算日期) AS 超期天数,
    ROUND(应收金额, 2) AS 应收金额,
    ROUND(未结算金额, 2) AS 未结算金额,
    业务类型
FROM MV_RECEIVABLE_SUMMARY
WHERE 未结算金额 > 0
    AND DATEDIFF(CURRENT_DATE(), 预计结算日期) > 0
ORDER BY 超期天数 DESC, 未结算金额 DESC;


-- =====================================================
-- 11.4 部门应收汇总
-- =====================================================
SELECT
    大部门名称,
    部门名称,
    COUNT(DISTINCT 客户主键) AS 客户数,
    ROUND(SUM(应收金额), 2) AS 应收总额,
    ROUND(SUM(未结算金额), 2) AS 未结算总额,
    ROUND(SUM(CASE WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) > 0 THEN 未结算金额 ELSE 0 END), 2) AS 超期金额,
    ROUND(
        SUM(CASE WHEN DATEDIFF(CURRENT_DATE(), 预计结算日期) > 0 THEN 未结算金额 ELSE 0 END)
        / NULLIF(SUM(未结算金额), 0) * 100, 2
    ) AS 超期占比
FROM MV_RECEIVABLE_SUMMARY
WHERE 未结算金额 > 0
GROUP BY 大部门名称, 部门名称
ORDER BY 超期金额 DESC;

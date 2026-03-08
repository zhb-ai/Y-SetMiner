-- =====================================================
-- 报表3: 客户活跃度监控
-- 业务价值: 预警客户流失，提升客户留存
-- MV依赖: MV_CUSTOMER_ACTIVITY
-- 更新频率: 每日
-- =====================================================

-- =====================================================
-- 3.1 客户活跃度总览
-- =====================================================
SELECT
    客户编码,
    客户名称,
    部门名称,
    业务员姓名,
    活跃状态,
    近30天订货天数,
    ROUND(近30天订货金额, 2) AS 近30天订货金额,
    近90天订货天数,
    ROUND(近90天订货金额, 2) AS 近90天订货金额,
    最后订货日期,
    距今天数,
    历史订单数,
    ROUND(历史订货总金额, 2) AS 历史订货总金额
FROM MV_CUSTOMER_ACTIVITY
ORDER BY 距今天数 DESC;


-- =====================================================
-- 3.2 活跃状态分布统计
-- =====================================================
SELECT
    活跃状态,
    COUNT(*) AS 客户数,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS 占比,
    ROUND(SUM(历史订货总金额), 2) AS 历史总金额,
    ROUND(AVG(历史订货总金额), 2) AS 平均客户金额
FROM MV_CUSTOMER_ACTIVITY
GROUP BY 活跃状态
ORDER BY
    CASE 活跃状态
        WHEN '活跃' THEN 1
        WHEN '一般' THEN 2
        WHEN '沉睡' THEN 3
        WHEN '流失' THEN 4
    END;


-- =====================================================
-- 3.3 按部门的活跃状态分布
-- =====================================================
SELECT
    部门名称,
    COUNT(*) AS 总客户数,
    SUM(CASE WHEN 活跃状态 = '活跃' THEN 1 ELSE 0 END) AS 活跃客户数,
    SUM(CASE WHEN 活跃状态 = '一般' THEN 1 ELSE 0 END) AS 一般客户数,
    SUM(CASE WHEN 活跃状态 = '沉睡' THEN 1 ELSE 0 END) AS 沉睡客户数,
    SUM(CASE WHEN 活跃状态 = '流失' THEN 1 ELSE 0 END) AS 流失客户数,
    ROUND(SUM(CASE WHEN 活跃状态 = '活跃' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS 活跃率
FROM MV_CUSTOMER_ACTIVITY
GROUP BY 部门名称
ORDER BY 活跃率 DESC;


-- =====================================================
-- 3.4 流失客户预警清单（沉睡+流失）
-- =====================================================
SELECT
    客户编码,
    客户名称,
    部门名称,
    业务员姓名,
    活跃状态,
    最后订货日期,
    距今天数,
    ROUND(历史订货总金额, 2) AS 历史订货总金额,
    历史订单数
FROM MV_CUSTOMER_ACTIVITY
WHERE 活跃状态 IN ('沉睡', '流失')
ORDER BY 历史订货总金额 DESC;


-- =====================================================
-- 3.5 业务员客户活跃度排名
-- =====================================================
SELECT
    业务员姓名,
    部门名称,
    COUNT(*) AS 管理客户数,
    SUM(CASE WHEN 活跃状态 = '活跃' THEN 1 ELSE 0 END) AS 活跃数,
    ROUND(SUM(CASE WHEN 活跃状态 = '活跃' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS 活跃率,
    SUM(CASE WHEN 活跃状态 IN ('沉睡', '流失') THEN 1 ELSE 0 END) AS 流失风险数,
    ROUND(SUM(近30天订货金额), 2) AS 近30天总金额
FROM MV_CUSTOMER_ACTIVITY
GROUP BY 业务员姓名, 部门名称
ORDER BY 活跃率 DESC;

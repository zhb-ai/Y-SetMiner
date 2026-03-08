-- =====================================================
-- 报表1: 销售业绩报表
-- 业务价值: 监控销售业绩,支持经营决策
-- 更新频率: 每日
-- =====================================================

-- =====================================================
-- 1.1 销售日报 (使用物化视图)
-- =====================================================
SELECT 
    日期,
    部门名称,
    业务员姓名,
    品牌,
    大类,
    品类,
    -- 核心指标
    SUM(销售数量) AS 销售数量,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(销售成本), 2) AS 销售成本,
    ROUND(SUM(毛利), 2) AS 毛利,
    -- 毛利率
    CASE 
        WHEN SUM(销售流水) = 0 THEN 0
        ELSE ROUND(SUM(毛利) / SUM(销售流水) * 100, 2)
    END AS 毛利率,
    -- 客户数
    COUNT(DISTINCT 客户主键) AS 客户数
FROM 
    MV_SALES_DETAIL
WHERE 
    日期 >= DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')  -- 本月开始
    AND 是否赠品 = 'N'
GROUP BY 
    日期,
    部门名称,
    业务员姓名,
    品牌,
    大类,
    品类
ORDER BY 
    日期 DESC,
    销售流水 DESC;


-- =====================================================
-- 1.2 销售月报 (使用物化视图)
-- =====================================================
SELECT 
    年月,
    部门名称,
    业务员姓名,
    品牌,
    大类,
    品类,
    -- 核心指标
    SUM(销售数量) AS 销售数量,
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(销售成本), 2) AS 销售成本,
    ROUND(SUM(毛利), 2) AS 毛利,
    -- 毛利率
    CASE 
        WHEN SUM(销售流水) = 0 THEN 0
        ELSE ROUND(SUM(毛利) / SUM(销售流水) * 100, 2)
    END AS 毛利率,
    -- 客户数
    客户数
FROM 
    MV_SALES_MONTHLY
WHERE 
    年月 >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m')
GROUP BY 
    年月,
    部门名称,
    业务员姓名,
    品牌,
    大类,
    品类,
    客户数
ORDER BY 
    年月 DESC,
    销售流水 DESC;


-- =====================================================
-- 1.3 销售业绩同比分析
-- =====================================================
WITH 本年数据 AS (
    SELECT 
        月份,
        部门名称,
        业务员姓名,
        大类,
        SUM(销售流水) AS 本年销售流水,
        SUM(毛利) AS 本年毛利
    FROM MV_SALES_MONTHLY
    WHERE 年度 = YEAR(CURRENT_DATE())
    GROUP BY 月份, 部门名称, 业务员姓名, 大类
),
去年数据 AS (
    SELECT 
        月份,
        部门名称,
        业务员姓名,
        大类,
        SUM(销售流水) AS 去年销售流水,
        SUM(毛利) AS 去年毛利
    FROM MV_SALES_MONTHLY
    WHERE 年度 = YEAR(CURRENT_DATE()) - 1
    GROUP BY 月份, 部门名称, 业务员姓名, 大类
)
SELECT 
    COALESCE(本年.月份, 去年.月份) AS 月份,
    COALESCE(本年.部门名称, 去年.部门名称) AS 部门名称,
    COALESCE(本年.业务员姓名, 去年.业务员姓名) AS 业务员姓名,
    COALESCE(本年.大类, 去年.大类) AS 大类,
    -- 本年数据
    ROUND(COALESCE(本年.本年销售流水, 0), 2) AS 本年销售流水,
    ROUND(COALESCE(本年.本年毛利, 0), 2) AS 本年毛利,
    -- 去年数据
    ROUND(COALESCE(去年.去年销售流水, 0), 2) AS 去年销售流水,
    ROUND(COALESCE(去年.去年毛利, 0), 2) AS 去年毛利,
    -- 同比增长率
    CASE 
        WHEN COALESCE(去年.去年销售流水, 0) = 0 THEN NULL
        ELSE ROUND((COALESCE(本年.本年销售流水, 0) - COALESCE(去年.去年销售流水, 0)) 
                   / COALESCE(去年.去年销售流水, 0) * 100, 2)
    END AS 销售流水同比增长率,
    CASE 
        WHEN COALESCE(去年.去年毛利, 0) = 0 THEN NULL
        ELSE ROUND((COALESCE(本年.本年毛利, 0) - COALESCE(去年.去年毛利, 0)) 
                   / COALESCE(去年.去年毛利, 0) * 100, 2)
    END AS 毛利同比增长率
FROM 
    本年数据 本年
    FULL OUTER JOIN 去年数据 去年
        ON 本年.月份 = 去年.月份
        AND 本年.部门名称 = 去年.部门名称
        AND 本年.业务员姓名 = 去年.业务员姓名
        AND 本年.大类 = 去年.大类
ORDER BY 
    月份,
    本年销售流水 DESC;


-- =====================================================
-- 1.4 销售业绩环比分析
-- =====================================================
WITH 本月数据 AS (
    SELECT 
        部门名称,
        业务员姓名,
        大类,
        SUM(销售流水) AS 本月销售流水,
        SUM(毛利) AS 本月毛利
    FROM MV_SALES_MONTHLY
    WHERE 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m')
    GROUP BY 部门名称, 业务员姓名, 大类
),
上月数据 AS (
    SELECT 
        部门名称,
        业务员姓名,
        大类,
        SUM(销售流水) AS 上月销售流水,
        SUM(毛利) AS 上月毛利
    FROM MV_SALES_MONTHLY
    WHERE 年月 = DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), '%Y-%m')
    GROUP BY 部门名称, 业务员姓名, 大类
)
SELECT 
    COALESCE(本月.部门名称, 上月.部门名称) AS 部门名称,
    COALESCE(本月.业务员姓名, 上月.业务员姓名) AS 业务员姓名,
    COALESCE(本月.大类, 上月.大类) AS 大类,
    -- 本月数据
    ROUND(COALESCE(本月.本月销售流水, 0), 2) AS 本月销售流水,
    ROUND(COALESCE(本月.本月毛利, 0), 2) AS 本月毛利,
    -- 上月数据
    ROUND(COALESCE(上月.上月销售流水, 0), 2) AS 上月销售流水,
    ROUND(COALESCE(上月.上月毛利, 0), 2) AS 上月毛利,
    -- 环比增长率
    CASE 
        WHEN COALESCE(上月.上月销售流水, 0) = 0 THEN NULL
        ELSE ROUND((COALESCE(本月.本月销售流水, 0) - COALESCE(上月.上月销售流水, 0)) 
                   / COALESCE(上月.上月销售流水, 0) * 100, 2)
    END AS 销售流水环比增长率,
    CASE 
        WHEN COALESCE(上月.上月毛利, 0) = 0 THEN NULL
        ELSE ROUND((COALESCE(本月.本月毛利, 0) - COALESCE(上月.上月毛利, 0)) 
                   / COALESCE(上月.上月毛利, 0) * 100, 2)
    END AS 毛利环比增长率
FROM 
    本月数据 本月
    FULL OUTER JOIN 上月数据 上月
        ON 本月.部门名称 = 上月.部门名称
        AND 本月.业务员姓名 = 上月.业务员姓名
        AND 本月.大类 = 上月.大类
ORDER BY 
    本月销售流水 DESC;


-- =====================================================
-- 1.5 销售业绩排名 (部门维度)
-- =====================================================
SELECT 
    部门名称,
    大部门名称,
    -- 本月数据
    ROUND(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END), 2) AS 本月销售流水,
    ROUND(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 毛利 ELSE 0 END), 2) AS 本月毛利,
    -- 本年累计
    ROUND(SUM(CASE WHEN 年度 = YEAR(CURRENT_DATE()) THEN 销售流水 ELSE 0 END), 2) AS 本年累计销售流水,
    ROUND(SUM(CASE WHEN 年度 = YEAR(CURRENT_DATE()) THEN 毛利 ELSE 0 END), 2) AS 本年累计毛利,
    -- 排名
    RANK() OVER (ORDER BY SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END) DESC) AS 本月排名,
    RANK() OVER (ORDER BY SUM(CASE WHEN 年度 = YEAR(CURRENT_DATE()) THEN 销售流水 ELSE 0 END) DESC) AS 本年排名
FROM 
    MV_SALES_MONTHLY
GROUP BY 
    部门名称,
    大部门名称
ORDER BY 
    本月销售流水 DESC;


-- =====================================================
-- 1.6 销售业绩排名 (业务员维度)
-- =====================================================
SELECT 
    业务员姓名,
    部门名称,
    -- 本月数据
    ROUND(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END), 2) AS 本月销售流水,
    ROUND(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 毛利 ELSE 0 END), 2) AS 本月毛利,
    SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 客户数 ELSE 0 END) AS 本月客户数,
    -- 本年累计
    ROUND(SUM(CASE WHEN 年度 = YEAR(CURRENT_DATE()) THEN 销售流水 ELSE 0 END), 2) AS 本年累计销售流水,
    ROUND(SUM(CASE WHEN 年度 = YEAR(CURRENT_DATE()) THEN 毛利 ELSE 0 END), 2) AS 本年累计毛利,
    -- 排名
    RANK() OVER (PARTITION BY 部门名称 ORDER BY SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END) DESC) AS 部门内排名,
    RANK() OVER (ORDER BY SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END) DESC) AS 全公司排名
FROM 
    MV_SALES_MONTHLY
GROUP BY 
    业务员姓名,
    部门名称
ORDER BY 
    本月销售流水 DESC;


-- =====================================================
-- 1.7 品类销售分析
-- =====================================================
SELECT 
    品牌,
    大类,
    品类,
    -- 本月数据
    ROUND(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END), 2) AS 本月销售流水,
    ROUND(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 毛利 ELSE 0 END), 2) AS 本月毛利,
    -- 毛利率
    CASE 
        WHEN SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END) = 0 THEN 0
        ELSE ROUND(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 毛利 ELSE 0 END) 
                   / SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END) * 100, 2)
    END AS 本月毛利率,
    -- 本年累计
    ROUND(SUM(CASE WHEN 年度 = YEAR(CURRENT_DATE()) THEN 销售流水 ELSE 0 END), 2) AS 本年累计销售流水,
    ROUND(SUM(CASE WHEN 年度 = YEAR(CURRENT_DATE()) THEN 毛利 ELSE 0 END), 2) AS 本年累计毛利,
    -- 占比
    ROUND(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END) 
          / SUM(SUM(CASE WHEN 年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') THEN 销售流水 ELSE 0 END)) OVER () * 100, 2) AS 销售占比
FROM 
    MV_SALES_MONTHLY
GROUP BY 
    品牌,
    大类,
    品类
ORDER BY 
    本月销售流水 DESC;


-- =====================================================
-- 1.8 销售趋势分析 (近12个月)
-- =====================================================
SELECT 
    年月,
    -- 总体指标
    ROUND(SUM(销售流水), 2) AS 销售流水,
    ROUND(SUM(毛利), 2) AS 毛利,
    CASE 
        WHEN SUM(销售流水) = 0 THEN 0
        ELSE ROUND(SUM(毛利) / SUM(销售流水) * 100, 2)
    END AS 毛利率,
    -- 按大类分组
    ROUND(SUM(CASE WHEN 大类 = '原装' THEN 销售流水 ELSE 0 END), 2) AS 原装销售流水,
    ROUND(SUM(CASE WHEN 大类 = '兼容' THEN 销售流水 ELSE 0 END), 2) AS 兼容销售流水,
    ROUND(SUM(CASE WHEN 大类 = '打印机' THEN 销售流水 ELSE 0 END), 2) AS 打印机销售流水
FROM 
    MV_SALES_MONTHLY
WHERE 
    年月 >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m')
GROUP BY 
    年月
ORDER BY 
    年月;


-- =====================================================
-- 1.9 目标完成率分析 (需要配合目标表)
-- =====================================================
-- 注: 此查询需要创建销售目标表 SALES_TARGET
-- 表结构: 年月, 部门名称, 业务员姓名, 目标销售额, 目标毛利

-- 示例查询 (假设已有目标表)
/*
SELECT 
    m.年月,
    m.部门名称,
    m.业务员姓名,
    -- 实际完成
    ROUND(SUM(m.销售流水), 2) AS 实际销售流水,
    ROUND(SUM(m.毛利), 2) AS 实际毛利,
    -- 目标
    t.目标销售额,
    t.目标毛利,
    -- 完成率
    CASE 
        WHEN t.目标销售额 = 0 THEN 0
        ELSE ROUND(SUM(m.销售流水) / t.目标销售额 * 100, 2)
    END AS 销售完成率,
    CASE 
        WHEN t.目标毛利 = 0 THEN 0
        ELSE ROUND(SUM(m.毛利) / t.目标毛利 * 100, 2)
    END AS 毛利完成率
FROM 
    MV_SALES_MONTHLY m
    LEFT JOIN SALES_TARGET t
        ON m.年月 = t.年月
        AND m.部门名称 = t.部门名称
        AND m.业务员姓名 = t.业务员姓名
WHERE 
    m.年月 = DATE_FORMAT(CURRENT_DATE(), '%Y-%m')
GROUP BY 
    m.年月,
    m.部门名称,
    m.业务员姓名,
    t.目标销售额,
    t.目标毛利
ORDER BY 
    销售完成率 DESC;
*/

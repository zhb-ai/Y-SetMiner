-- =====================================================
-- 报表18: 放货业务管理
-- 业务价值: 监控已发货未开票业务，控制放货风险
-- MV依赖: 无（直接查询基表）
-- 更新频率: 每日
-- 说明: 放货 = 已出库但未开发票（或已出库未结算）
--       基于销售订单(SO_SALE)的状态字段判断
--       boutendflag 出库关闭标记, binvoicendflag 开票关闭标记
-- =====================================================

-- =====================================================
-- 18.1 放货客户汇总
-- =====================================================
SELECT
    cust.custname AS 客户名称,
    cust.custcode AS 客户编码,
    cust.psnname AS 业务员,
    cust.deptname AS 市场部,
    COUNT(DISTINCT so.csaleid) AS 放货单数,
    ROUND(SUM(so.nheadsummny), 2) AS 放货总金额,
    MIN(so.dbilldate) AS 最早放货日期,
    MAX(DATEDIFF(CURRENT_DATE(), CAST(so.dbilldate AS DATE))) AS 最长放货天数
FROM SO_SALE so
INNER JOIN v_zlw_cust cust
    ON so.ccustomerid = cust.pk_cumandoc
LEFT JOIN BD_BUSITYPE btp
    ON so.cbiztype = btp.pk_busitype
    AND btp.dr = 0
WHERE so.pk_corp = '1006'
    AND so.dr = 0
    AND so.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND so.fstatus >= 3
    AND so.boutendflag = 'Y'
    AND so.binvoicendflag = 'N'
GROUP BY cust.custname, cust.custcode, cust.psnname, cust.deptname
ORDER BY 放货总金额 DESC;


-- =====================================================
-- 18.2 放货明细清单
-- =====================================================
SELECT
    so.vreceiptcode AS 订单号,
    so.dbilldate AS 单据日期,
    cust.custname AS 客户名称,
    cust.psnname AS 业务员,
    cust.deptname AS 市场部,
    btp.businame AS 业务类型,
    ROUND(so.nheadsummny, 2) AS 订单金额,
    DATEDIFF(CURRENT_DATE(), CAST(so.dbilldate AS DATE)) AS 放货天数,
    CASE
        WHEN DATEDIFF(CURRENT_DATE(), CAST(so.dbilldate AS DATE)) > 30 THEN '严重超期'
        WHEN DATEDIFF(CURRENT_DATE(), CAST(so.dbilldate AS DATE)) > 15 THEN '超期'
        WHEN DATEDIFF(CURRENT_DATE(), CAST(so.dbilldate AS DATE)) > 7 THEN '预警'
        ELSE '正常'
    END AS 风险等级
FROM SO_SALE so
INNER JOIN v_zlw_cust cust
    ON so.ccustomerid = cust.pk_cumandoc
LEFT JOIN BD_BUSITYPE btp
    ON so.cbiztype = btp.pk_busitype
    AND btp.dr = 0
WHERE so.pk_corp = '1006'
    AND so.dr = 0
    AND so.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND so.fstatus >= 3
    AND so.boutendflag = 'Y'
    AND so.binvoicendflag = 'N'
ORDER BY 放货天数 DESC;


-- =====================================================
-- 18.3 放货部门汇总
-- =====================================================
SELECT
    dept.deptname AS 部门名称,
    COUNT(DISTINCT so.csaleid) AS 放货单数,
    COUNT(DISTINCT so.ccustomerid) AS 放货客户数,
    ROUND(SUM(so.nheadsummny), 2) AS 放货总金额,
    ROUND(AVG(DATEDIFF(CURRENT_DATE(), CAST(so.dbilldate AS DATE))), 1) AS 平均放货天数,
    SUM(CASE WHEN DATEDIFF(CURRENT_DATE(), CAST(so.dbilldate AS DATE)) > 30 THEN 1 ELSE 0 END) AS 超30天单数
FROM SO_SALE so
INNER JOIN BD_DEPTDOC dept
    ON so.cdeptid = dept.pk_deptdoc
    AND dept.dr = 0
WHERE so.pk_corp = '1006'
    AND so.dr = 0
    AND so.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND so.fstatus >= 3
    AND so.boutendflag = 'Y'
    AND so.binvoicendflag = 'N'
GROUP BY dept.deptname
ORDER BY 放货总金额 DESC;


-- =====================================================
-- 18.4 放货月度趋势
-- =====================================================
SELECT
    DATE_FORMAT(so.dbilldate, '%Y-%m') AS 年月,
    COUNT(DISTINCT so.csaleid) AS 放货单数,
    COUNT(DISTINCT so.ccustomerid) AS 放货客户数,
    ROUND(SUM(so.nheadsummny), 2) AS 放货金额
FROM SO_SALE so
WHERE so.pk_corp = '1006'
    AND so.dr = 0
    AND so.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND so.fstatus >= 3
    AND so.boutendflag = 'Y'
    AND so.binvoicendflag = 'N'
    AND so.dbilldate >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m-01')
GROUP BY DATE_FORMAT(so.dbilldate, '%Y-%m')
ORDER BY 年月;

-- =====================================================
-- 物化视图8: 客户活跃度统计 (MV_CUSTOMER_ACTIVITY)
-- 用途: 客户活跃度监控与流失预警
-- 刷新策略: 每日定时 (DEFERRED ASYNC EVERY 1 DAY)
-- 服务报表: 客户活跃度监控
-- 数据源: SO_SALEINVOICE (发票)，统计近一年订货行为
-- 说明: 活跃状态等含CURRENT_DATE()的字段在每日刷新时更新，精度为T+1
-- =====================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS MV_CUSTOMER_ACTIVITY
COMMENT '客户活跃度统计 - 基于发票的客户活跃度与流失预警'
DISTRIBUTED BY HASH(客户主键) BUCKETS 32
ORDER BY (客户主键)
REFRESH DEFERRED ASYNC EVERY (INTERVAL 1 DAY)
PROPERTIES (
    "enable_spill" = "true",
    "mv_rewrite_staleness_second" = "86400",
    "excluded_trigger_tables" = "BD_PSNDOC,BD_DEPTDOC,BD_CUBASDOC,BD_CUMANDOC"
)
AS
SELECT
    cumbase.pk_cubasdoc AS 客户主键,
    cumbase.custcode AS 客户编码,
    cumbase.custname AS 客户名称,

    dept.deptname AS 部门名称,
    psn.psncode AS 业务员编码,
    psn.psnname AS 业务员姓名,

    COUNT(DISTINCT CASE
        WHEN ii.dbilldate >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
        THEN ii.dbilldate
    END) AS 近30天订货天数,

    SUM(CASE
        WHEN ii.dbilldate >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
        THEN ib.nsummny
        ELSE 0
    END) AS 近30天订货金额,

    COUNT(DISTINCT CASE
        WHEN ii.dbilldate >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
        THEN ii.dbilldate
    END) AS 近90天订货天数,

    SUM(CASE
        WHEN ii.dbilldate >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
        THEN ib.nsummny
        ELSE 0
    END) AS 近90天订货金额,

    MAX(ii.dbilldate) AS 最后订货日期,

    DATEDIFF(CURRENT_DATE(), MAX(ii.dbilldate)) AS 距今天数,

    CASE
        WHEN MAX(ii.dbilldate) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) THEN '活跃'
        WHEN MAX(ii.dbilldate) >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY) THEN '一般'
        WHEN MAX(ii.dbilldate) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) THEN '沉睡'
        ELSE '流失'
    END AS 活跃状态,

    COUNT(DISTINCT ii.csaleid) AS 历史订单数,

    SUM(ib.nsummny) AS 历史订货总金额

FROM
    SO_SALEINVOICE ii
    INNER JOIN SO_SALEINVOICE_B ib
        ON ii.csaleid = ib.csaleid
        AND ib.dr = 0
    INNER JOIN BD_CUMANDOC cuman
        ON ii.creceiptcustomerid = cuman.pk_cumandoc
        AND cuman.pk_corp = '1006'
        AND cuman.dr = 0
    INNER JOIN BD_CUBASDOC cumbase
        ON cuman.pk_cubasdoc = cumbase.pk_cubasdoc
        AND cumbase.dr = 0
    LEFT JOIN BD_PSNDOC psn
        ON cuman.pk_resppsn1 = psn.pk_psndoc
        AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept
        ON cuman.pk_respdept1 = dept.pk_deptdoc
        AND dept.dr = 0
WHERE
    ii.pk_corp = '1006'
    AND ii.dr = 0
    AND ii.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND ii.dbilldate >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
GROUP BY
    cumbase.pk_cubasdoc,
    cumbase.custcode,
    cumbase.custname,
    dept.deptname,
    psn.psncode,
    psn.psnname;

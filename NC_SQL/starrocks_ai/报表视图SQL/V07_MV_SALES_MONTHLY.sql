-- =====================================================
-- 物化视图7: 销售月汇总表 (MV_SALES_MONTHLY)
-- 用途: 月度分析、同比环比
-- 刷新策略: 每日定时 (DEFERRED ASYNC EVERY 1 DAY)
-- 服务报表: 销售业绩、毛利分析
-- 说明: 毛利率在查询层通过 ROUND(毛利/NULLIF(销售流水,0)*100, 2) 实时计算
-- =====================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS MV_SALES_MONTHLY
COMMENT '销售月汇总表 - 月度分析与同比环比'
DISTRIBUTED BY HASH(年月, 部门主键) BUCKETS 32
ORDER BY (年月, 部门主键, 业务员主键)
REFRESH DEFERRED ASYNC EVERY (INTERVAL 1 DAY)
PROPERTIES (
    "enable_spill" = "true",
    "mv_rewrite_staleness_second" = "86400",
    "excluded_trigger_tables" = "BD_PSNDOC,BD_DEPTDOC,BD_CUBASDOC,BD_AREACL,BD_BUSITYPE"
)
AS
SELECT
    DATE_FORMAT(sq.dmakedate, '%Y-%m') AS 年月,
    YEAR(sq.dmakedate) AS 年度,
    MONTH(sq.dmakedate) AS 月份,

    dept.pk_deptdoc AS 部门主键,
    dept.deptname AS 部门名称,
    fdept.deptname AS 大部门名称,
    psn.pk_psndoc AS 业务员主键,
    psn.psncode AS 业务员编码,
    psn.psnname AS 业务员姓名,

    invbas.invpinpai AS 品牌,
    invbas.width AS 大类,
    invbas.length AS 品类,

    btp.businame AS 业务类型,

    COUNT(DISTINCT cumbase.pk_cubasdoc) AS 客户数,
    COUNT(DISTINCT sq.pk_squaredetail) AS 订单数,

    SUM(sq.noutnum) AS 销售数量,

    SUM(
        CASE
            WHEN sq.blargessflag = 'Y' THEN 0
            WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
            ELSE
                ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
        END
    ) AS 销售流水,

    SUM(sq.ncostmny) AS 销售成本,

    SUM(
        CASE
            WHEN sq.blargessflag = 'Y' THEN 0
            WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2) - sq.ncostmny
            ELSE
                ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2) - sq.ncostmny
        END
    ) AS 毛利

FROM
    SO_SQUAREDETAIL sq
    INNER JOIN BD_INVMANDOC invman
        ON sq.cinventoryid = invman.pk_invmandoc
        AND invman.pk_corp = '1006'
        AND invman.dr = 0
    INNER JOIN BD_INVBASDOC invbas
        ON invman.pk_invbasdoc = invbas.pk_invbasdoc
        AND invbas.dr = 0
    LEFT JOIN BD_CUMANDOC cuman
        ON sq.ccustomerid = cuman.pk_cumandoc
        AND cuman.pk_corp = '1006'
        AND cuman.dr = 0
    LEFT JOIN BD_CUBASDOC cumbase
        ON cuman.pk_cubasdoc = cumbase.pk_cubasdoc
        AND cumbase.dr = 0
    LEFT JOIN BD_PSNDOC psn
        ON sq.cemployeeid = psn.pk_psndoc
        AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept
        ON sq.cdeptid = dept.pk_deptdoc
        AND dept.dr = 0
    LEFT JOIN BD_DEPTDOC fdept
        ON dept.pk_fathedept = fdept.pk_deptdoc
        AND fdept.dr = 0
    LEFT JOIN BD_BUSITYPE btp
        ON sq.cbiztype = btp.pk_busitype
        AND btp.dr = 0
WHERE
    sq.pk_corp = '1006'
    AND sq.dr = 0
    AND sq.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND SUBSTR(invbas.invcode, 1, 2) != '98'
    AND invbas.width IN ('兼容', '原装', '打印机', '电脑PC')
GROUP BY
    DATE_FORMAT(sq.dmakedate, '%Y-%m'),
    YEAR(sq.dmakedate),
    MONTH(sq.dmakedate),
    dept.pk_deptdoc,
    dept.deptname,
    fdept.deptname,
    psn.pk_psndoc,
    psn.psncode,
    psn.psnname,
    invbas.invpinpai,
    invbas.width,
    invbas.length,
    btp.businame;

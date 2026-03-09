-- =====================================================
-- 物化视图1: 销售明细宽表 (MV_SALES_DETAIL)
-- 用途: 支持所有销售分析报表的基础宽表
-- 刷新策略: 每日定时 (DEFERRED ASYNC EVERY 1 DAY)
-- 服务报表: 销售业绩、客户价值、业务员绩效、品类销售、毛利分析
-- =====================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS MV_SALES_DETAIL
COMMENT '销售明细宽表 - 支持所有销售分析报表'
DISTRIBUTED BY HASH(销售结算主键) BUCKETS 32
ORDER BY (制单日期, 部门主键, 客户主键)
REFRESH DEFERRED ASYNC EVERY (INTERVAL 1 DAY)
PROPERTIES (
    "enable_spill" = "true",
    "mv_rewrite_staleness_second" = "86400",
    "excluded_trigger_tables" = "BD_PSNDOC,BD_DEPTDOC,BD_CUBASDOC,BD_AREACL,BD_BUSITYPE"
)
AS
SELECT
    sq.pk_squaredetail AS 销售结算主键,
    sq.csaleid AS 结算单主键,
    sq.dmakedate AS 制单日期,
    DATE_FORMAT(sq.dmakedate, '%Y-%m-%d') AS 日期,
    DATE_FORMAT(sq.dmakedate, '%Y-%m') AS 年月,
    YEAR(sq.dmakedate) AS 年度,
    MONTH(sq.dmakedate) AS 月份,

    cumbase.pk_cubasdoc AS 客户主键,
    cumbase.custcode AS 客户编码,
    cumbase.custname AS 客户名称,
    CASE
        WHEN cumbase.def3 = '0001C11000000012TJ3X' THEN 'Y'
        ELSE 'N'
    END AS 是否商桥,

    dept.pk_deptdoc AS 部门主键,
    dept.deptname AS 部门名称,
    fdept.deptname AS 大部门名称,
    psn.pk_psndoc AS 业务员主键,
    psn.psncode AS 业务员编码,
    psn.psnname AS 业务员姓名,

    dq.sf AS 省份,
    dq.cs AS 城市,

    invbas.pk_invbasdoc AS 商品主键,
    invbas.invcode AS 商品编码,
    invbas.invname AS 商品名称,
    invbas.invpinpai AS 品牌,
    invbas.width AS 大类,
    invbas.length AS 品类,
    invbas.height AS 小类,
    invbas.invspec AS 规格,
    invbas.invtype AS 型号,

    btp.pk_busitype AS 业务类型主键,
    btp.businame AS 业务类型名称,

    sq.noutnum AS 销售数量,
    sq.blargessflag AS 是否赠品,

    CASE
        WHEN sq.blargessflag = 'Y' THEN 0
        WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
            ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
        ELSE
            ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
    END AS 销售流水,

    sq.ncostmny AS 销售成本,

    CASE
        WHEN sq.blargessflag = 'Y' THEN 0
        WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
            ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2) - sq.ncostmny
        ELSE
            ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2) - sq.ncostmny
    END AS 毛利,

    sq.noriginalcurmny AS 原币无税金额,
    sq.nsummny AS 本币价税合计,
    sq.ntaxrate AS 税率,
    sq.vbodydef5 AS 自定义单价

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
    LEFT JOIN (
        SELECT
            cl.pk_areacl,
            c.areaclname AS sf,
            cl.areaclname AS cs
        FROM BD_AREACL c
        INNER JOIN BD_AREACL cl
            ON c.pk_areacl = cl.pk_fatherarea
            AND c.dr = 0
            AND cl.dr = 0
    ) dq ON cumbase.pk_areacl = dq.pk_areacl
WHERE
    sq.pk_corp = '1006'
    AND sq.dr = 0
    AND sq.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND SUBSTR(invbas.invcode, 1, 2) != '98'
    AND invbas.width IN ('兼容', '原装', '打印机', '电脑PC');

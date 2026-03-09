-- =====================================================
-- 物化视图3: 应收账款汇总表 (MV_RECEIVABLE_SUMMARY)
-- 用途: 应收账款分析、账龄计算
-- 刷新策略: 每日定时 (DEFERRED ASYNC EVERY 1 DAY)
-- 服务报表: 应收账龄、客户信用管理
-- 说明: 超期天数在查询层通过 DATEDIFF(CURRENT_DATE(), 预计结算日期) 实时计算
-- =====================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS MV_RECEIVABLE_SUMMARY
COMMENT '应收账款汇总表 - 应收账龄与信用管理'
DISTRIBUTED BY HASH(客户主键) BUCKETS 32
ORDER BY (单据日期, 客户主键)
REFRESH DEFERRED ASYNC EVERY (INTERVAL 1 DAY)
PROPERTIES (
    "enable_spill" = "true",
    "mv_rewrite_staleness_second" = "86400",
    "excluded_trigger_tables" = "BD_PSNDOC,BD_DEPTDOC,BD_CUBASDOC,BD_AREACL,BD_PAYTERM"
)
AS
SELECT
    ss.csaleid AS 结算单主键,

    cumbase.pk_cubasdoc AS 客户主键,
    cumbase.custcode AS 客户编码,
    cumbase.custname AS 客户名称,

    dept.pk_deptdoc AS 部门主键,
    dept.deptname AS 部门名称,
    fdept.deptname AS 大部门名称,
    psn.pk_psndoc AS 业务员主键,
    psn.psncode AS 业务员编码,
    psn.psnname AS 业务员姓名,

    ss.vreceiptcode AS 结算单号,
    COALESCE(so.vreceiptcode, sy.vreceiptcode) AS 源单号,
    ss.dbilldate AS 单据日期,
    ss.vdef11 AS 属性,
    ss.vdef5 AS 销方公司,

    CAST(COALESCE(term.termid, '0') AS INT) AS 账期天数,
    term.termname AS 付款协议,

    DATE_ADD(
        CAST(ss.dbilldate AS DATE),
        INTERVAL CAST(COALESCE(term.termid, '0') AS INT) DAY
    ) AS 预计结算日期,

    SUM(
        CASE
            WHEN IFNULL(sb.blargessflag, 'N') = 'N' THEN sb.nsummny
            ELSE 0
        END
    ) AS 应收金额,

    SUM(
        CASE
            WHEN IFNULL(sb.noutnum, 0) != IFNULL(sb.nbalancenum, 0)
                AND IFNULL(sb.blargessflag, 'N') = 'N'
            THEN sb.nsummny
            ELSE 0
        END
    ) AS 未结算金额,

    btp.businame AS 业务类型

FROM
    SO_SQUARE ss
    INNER JOIN SO_SQUARE_B sb
        ON ss.csaleid = sb.csaleid
        AND sb.dr = 0
    LEFT JOIN SO_SALE so
        ON sb.csourcebillid = so.csaleid
        AND so.dr = 0
    LEFT JOIN SO_APPLY sy
        ON sb.csourcebillid = sy.pk_apply
        AND sy.dr = 0
    LEFT JOIN BD_PAYTERM term
        ON ss.ctermprotocolid = term.pk_payterm
        AND term.pk_corp = '1006'
        AND term.dr = 0
    LEFT JOIN BD_CUMANDOC cuman
        ON ss.ccustomerid = cuman.pk_cumandoc
        AND cuman.pk_corp = '1006'
        AND cuman.dr = 0
    LEFT JOIN BD_CUBASDOC cumbase
        ON cuman.pk_cubasdoc = cumbase.pk_cubasdoc
        AND cumbase.dr = 0
    LEFT JOIN BD_PSNDOC psn
        ON ss.cemployeeid = psn.pk_psndoc
        AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept
        ON ss.cdeptid = dept.pk_deptdoc
        AND dept.dr = 0
    LEFT JOIN BD_DEPTDOC fdept
        ON dept.pk_fathedept = fdept.pk_deptdoc
        AND fdept.dr = 0
    LEFT JOIN BD_BUSITYPE btp
        ON ss.cbiztype = btp.pk_busitype
        AND btp.dr = 0
WHERE
    ss.pk_corp = '1006'
    AND ss.dr = 0
    AND ss.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
GROUP BY
    ss.csaleid,
    cumbase.pk_cubasdoc,
    cumbase.custcode,
    cumbase.custname,
    dept.pk_deptdoc,
    dept.deptname,
    fdept.deptname,
    psn.pk_psndoc,
    psn.psncode,
    psn.psnname,
    ss.vreceiptcode,
    so.vreceiptcode,
    sy.vreceiptcode,
    ss.dbilldate,
    ss.vdef11,
    ss.vdef5,
    term.termid,
    term.termname,
    btp.businame;

-- =====================================================
-- 商品库存周转分析表
-- 结合现有SQL体系，整合库存、出库、销售数据
-- 计算周转天数、周转率、库存健康度等核心指标
-- =====================================================

-- 基础参数设置
WITH PARAMS AS (
    SELECT 
        TO_CHAR(SYSDATE - 90, 'YYYY-MM-DD') AS START_DATE,  -- 分析起始日期（近90天）
        TO_CHAR(SYSDATE - 1, 'YYYY-MM-DD') AS END_DATE,      -- 分析截止日期
        90 AS ANALYSIS_DAYS                                    -- 分析天数
    FROM DUAL
),

-- =====================================================
-- 第一层：商品基础维度信息（原子性维度）
-- 来源：bd_invbasdoc + bd_invmandoc
-- =====================================================
PRODUCT_DIM AS (
    SELECT 
        AA.PK_INV BASDOC AS 存货主键,
        AA.INVCODE AS 存货编码,
        AA.INVNAME AS 存货名称,
        AA.INVPINPAI AS 品牌,
        AA.WIDTH AS 大类,
        AA.LENGTH AS 品类,
        AA.HEIGHT AS 规格,
        AA.DEF10 AS 供应商,
        AA.DEF2 AS 装箱量,
        BB.REFSALEPRICE AS 参考售价,
        BB.LOWESTPRICE AS 最低售价,
        CASE 
            WHEN AA.DEF8 NOT LIKE '%非备货%' THEN '是' 
            ELSE '否' 
        END AS 是否备货,
        BB.SEALFLAG AS 是否封存
    FROM NC5X.BD_INVBASDOC AA
    JOIN NC5X.BD_INVMANDOC BB 
        ON AA.PK_INVBASDOC = BB.PK_INVBASDOC
    WHERE BB.SEALFLAG = 'N'
        AND LENGTH(AA.INVCODE) > 4
        AND AA.INVCODE NOT IN ('9805', '9810', '9807', '9809', '9899', '9898')
),

-- =====================================================
-- 第二层：仓库维度映射（统一仓库归属）
-- 参考现有现存量.sql中的仓库分组逻辑
-- =====================================================
WAREHOUSE_DIM AS (
    SELECT 
        PK_STORDOC AS 仓库主键,
        STORNAME AS 仓库名称,
        STORCODE AS 仓库编码,
        CASE 
            WHEN STORNAME IN ('1号库', '北京耐力办公一库', '京东pop账号-FBP-协同仓-1号库', 
                              '盛辉3A003', '盛辉2-650', '耐 力备件库', '耐力备件',
                              '京东pop账号-FBP-北京仓', '京东pop账号-SOP-北京仓',
                              '盛辉3H006', '百旺仓', '维修站-北京原装耗材库',
                              '维修站-北京打印机库', '99库', '维修站-备件库',
                              '京东直发仓', '北京协同仓', '盛 辉2-650备件库',
                              '1 号库备件库', '盛 辉3A003备件库', '维修站-广州备件库',
                              '北京新中关库', '百旺仓-京东协同仓') THEN '北京'
            WHEN STORNAME IN ('成 都仓库', '成都仓库', '成 都仓库备件库', 
                              '成 都耐力备件', '成 都99库') THEN '成都'
            WHEN STORNAME IN ('呼和浩特仓库', '呼 和浩特仓库备件库') THEN '呼和浩特'
            WHEN STORNAME IN ('南京仓库', '京东pop账号-SOP-上海仓', '京东pop账号-SOP-广州仓',
                              '京东pop账号-SOP-武汉仓', '成 都耐力备件', '京东pop账号-FBP-广州仓',
                              '京东pop账号-FBP-上海仓', '京东pop账号-FBP-武汉仓',
                              '维修站-南京仓库', '呼 都99库', '呼 和浩特仓库备件库') THEN '南京'
            WHEN STORNAME IN ('广 州仓库', '广州仓库', '广 州仓库备件库',
                              '广 都99库', '维修站-广州仓库', '广 州新中关备件库') THEN '广州'
            WHEN STORNAME IN ('沈阳仓库', '沈阳盛辉', '沈 阳仓库备件库', '沈 都99库') THEN '沈阳'
            WHEN STORNAME IN ('唐山仓库', '唐山99库') THEN '唐山'
            WHEN STORNAME IN ('济南仓库', '济 南仓库备件库') THEN '济南'
            ELSE '其他'
        END AS 所属区域
    FROM NC5X.BD_STORDOC
    WHERE STORNAME IN (
        '1号库', '成都仓库', '呼和浩特仓库', '南京仓库', '广州仓库',
        '沈阳仓库', '唐山仓库', '济南仓库', '99库', '百旺仓',
        '盛辉2-650', '盛辉3A003', '盛辉3H006'
    )
),

-- =====================================================
-- 第三层：现存量数据（当前库存）
-- 来源：ic_onhandnum
-- =====================================================
CURRENT_STOCK AS (
    SELECT 
        AA.CINVBASID AS 存货主键,
        AA.CWAREHOUSEID AS 仓库主键,
        SUM(AA.NONHANDNUM) AS 现存数量,
        SUM(AA.NONHANDNUM * NVL(BB.REF SALEPRICE, 0)) AS 库存金额
    FROM NC5X.IC_ONHANDNUM AA
    JOIN NC5X.BD_INVMANDOC BB 
        ON AA.CINVENTORYID = BB.PK_INVMANDOC
    WHERE AA.NONHANDNUM <> 0
    GROUP BY AA.CINVBASID, AA.CWAREHOUSEID
),

-- =====================================================
-- 第四层：出库数据（销售出库）
-- 来源：so_saleinvoice + so_saleinvoice_b
-- 参考：各仓出库周转底表.sql
-- =====================================================
OUTBOUND_DATA AS (
    SELECT 
        IB.CINVBASDOCID AS 存货主键,
        II.CWAREHOUSEID AS 仓库主键,
        SUM(IB.NNUMBER) AS 出库数量,
        SUM(ROUND(
            (CASE 
                WHEN TO_NUMBER(IB.NNUMBER * IB.VBODYDEF5) = 0 
                    OR IB.NNUMBER * IB.VBODYDEF5 IS NULL 
                THEN IB.NSUMMNY 
                ELSE IB.NNUMBER * IB.VBODYDEF5 
            END) / (IB.NTAXRATE * 0.01 + 1), 
        2)) AS 出库流水,
        COUNT(DISTINCT II.CSALEID) AS 出库单数,
        COUNT(DISTINCT II.CRECEIP TCUSTOMERID) AS 出库客户数
    FROM NC5X.SO_SALEINVOICE II
    JOIN (
        SELECT 
            IB.CSALEID, 
            IB.NNUMBER, 
            IB.NSUMMNY, 
            IB.VBODYDEF5,
            IB.NTAXRATE,
            CH.INVPINPAI,
            CH.HEIGHT,
            CH.WIDTH,
            CH.LENGTH,
            CH.INVNAME,
            CH.INVCODE,
            IB.BLARGESSFLAG,
            CH.PK_INVBASDOC AS CINVBASDOCID
        FROM NC5X.SO_SALEINVOICE_B IB
        JOIN NC5X.BD_INVBASDOC CH
            ON IB.CINVBASDOCID = CH.PK_INVBASDOC
    ) IB ON IB.CSALEID = II.CSALEID
    JOIN PARAMS P ON II.DBILLDATE BETWEEN P.START_DATE AND P.END_DATE
    WHERE II.DR = 0
        AND IB.WIDTH IN ('原装', '兼容', '打印机', '联想PC', '智能家居')
        AND LENGTH(IB.INVCODE) >= 6
    GROUP BY IB.CINVBASDOCID, II.CWAREHOUSEID
),

-- =====================================================
-- 第五层：入库数据（采购入库）
-- 来源：ic_general_h + ic_general_b
-- 参考：采购入库.sql
-- =====================================================
INBOUND_DATA AS (
    SELECT 
        IGB.CINVBASID AS 存货主键,
        IGH.CWAREHOUSEID AS 仓库主键,
        SUM(NVL(IGB.NINNUM, 0)) AS 入库数量,
        COUNT(DISTINCT IGH.CGENERALHID) AS 入库单数,
        MAX(IGH.DBILLDATE) AS 最后入库日期
    FROM NC5X.IC_GENERAL_H IGH
    JOIN NC5X.IC_GENERAL_B IGB
        ON IGH.CGENERALHID = IGB.CGENERALHID
        AND IGB.DR = 0 
        AND IGH.FBILLFLAG >= 3
    JOIN NC5X.BD_BILLTYPE BT
        ON IGH.CBILLTYPECODE = BT.PK_BILLTYPECODE
    JOIN PARAMS P ON IGH.DBILLDATE BETWEEN P.START_DATE AND P.END_DATE
    WHERE BT.BILLTYPENAME LIKE '%采购%'
        OR BT.BILLTYPENAME LIKE '%入库%'
    GROUP BY IGB.CINVBASID, IGH.CWAREHOUSEID
),

-- =====================================================
-- 第六层：计算周转指标
-- =====================================================
TURNOVER_CALC AS (
    SELECT 
        PD.*,
        WD.仓库主键,
        WD.仓库名称,
        WD.所属区域,
        
        -- 当前库存
        NVL(CS.现存数量, 0) AS 现存数量,
        NVL(CS.库存金额, 0) AS 库存金额,
        
        -- 出库数据
        NVL(OD.出库数量, 0) AS 近90天出库数量,
        NVL(OD.出库流水, 0) AS 近90天出库流水,
        NVL(OD.出库单数, 0) AS 近90天出库单数,
        NVL(OD.出库客户数, 0) AS 近90天出库客户数,
        
        -- 入库数据
        NVL(ID.入库数量, 0) AS 近90天入库数量,
        NVL(ID.入库单数, 0) AS 近90天入库单数,
        ID.最后入库日期,
        
        -- 周转天数计算
        CASE 
            WHEN NVL(OD.出库数量, 0) = 0 THEN 9999
            ELSE ROUND(NVL(CS.现存数量, 0) / (OD.出库数量 / 90), 2)
        END AS 周转天数,
        
        -- 周转率计算（年周转次数）
        CASE 
            WHEN NVL(CS.现存数量, 0) = 0 THEN 0
            ELSE ROUND((OD.出库数量 / 90 * 365) / NVL(CS.现存数量, 0), 2)
        END AS 年周转率,
        
        -- 日均出库量
        CASE 
            WHEN NVL(OD.出库数量, 0) = 0 THEN 0
            ELSE ROUND(OD.出库数量 / 90, 2)
        END AS 日均出库量,
        
        -- 库存可销天数
        CASE 
            WHEN NVL(OD.出库数量, 0) = 0 THEN 9999
            ELSE ROUND(NVL(CS.现存数量, 0) / (OD.出库数量 / 90), 0)
        END AS 可销天数,
        
        -- 库存健康度评级
        CASE 
            WHEN NVL(OD.出库数量, 0) = 0 AND NVL(CS.现存数量, 0) > 0 THEN '滞销'
            WHEN ROUND(NVL(CS.现存数量, 0) / (OD.出库数量 / 90), 0) <= 15 THEN '优秀'
            WHEN ROUND(NVL(CS.现存数量, 0) / (OD.出库数量 / 90), 0) <= 30 THEN '良好'
            WHEN ROUND(NVL(CS.现存数量, 0) / (OD.出库数量 / 90), 0) <= 60 THEN '一般'
            WHEN ROUND(NVL(CS.现存数量, 0) / (OD.出库数量 / 90), 0) <= 90 THEN '预警'
            ELSE '滞销'
        END AS 库存健康度,
        
        -- 库存状态
        CASE 
            WHEN NVL(CS.现存数量, 0) = 0 THEN '缺货'
            WHEN NVL(OD.出库数量, 0) = 0 THEN '呆滞'
            ELSE '正常'
        END AS 库存状态,
        
        -- 建议补货量（基于30天安全库存）
        CASE 
            WHEN NVL(OD.出库数量, 0) = 0 THEN 0
            WHEN ROUND(NVL(CS.现存数量, 0) / (OD.出库数量 / 90), 0) < 15 
                THEN ROUND((OD.出库数量 / 90 * 30) - NVL(CS.现存数量, 0), 0)
            ELSE 0
        END AS 建议补货量
        
    FROM PRODUCT_DIM PD
    LEFT JOIN CURRENT_STOCK CS 
        ON PD.存货主键 = CS.存货主键
    LEFT JOIN WAREHOUSE_DIM WD 
        ON CS.仓库主键 = WD.仓库主键
    LEFT JOIN OUTBOUND_DATA OD 
        ON PD.存货主键 = OD.存货主键 
        AND CS.仓库主键 = OD.仓库主键
    LEFT JOIN INBOUND_DATA ID 
        ON PD.存货主键 = ID.存货主键 
        AND CS.仓库主键 = ID.仓库主键
    WHERE NVL(CS.现存数量, 0) > 0  -- 只显示有库存的商品
)

-- =====================================================
-- 最终输出：商品库存周转分析表
-- =====================================================
SELECT 
    存货编码,
    存货名称,
    品牌,
    大类,
    品类,
    规格,
    供应商,
    所属区域,
    仓库名称,
    
    -- 库存现状
    现存数量,
    库存金额,
    参考售价,
    
    -- 出库情况
    近90天出库数量,
    近90天出库流水,
    近90天出库单数,
    近90天出库客户数,
    日均出库量,
    
    -- 入库情况
    近90天入库数量,
    最后入库日期,
    
    -- 周转指标
    周转天数,
    年周转率,
    可销天数,
    
    -- 健康度评估
    库存健康度,
    库存状态,
    建议补货量,
    
    -- 是否备货标识
    是否备货

FROM TURNOVER_CALC
WHERE 1=1
    -- 可按需添加过滤条件
    -- AND 周转天数 > 30
    -- AND 库存健康度 = '预警'
    -- AND 所属区域 = '北京'
    -- AND 品牌 = '惠普'

ORDER BY 
    库存金额 DESC,      -- 按库存金额降序
    周转天数 DESC;      -- 周转慢的优先显示


-- =====================================================
-- 扩展：按区域汇总统计
-- =====================================================
/*
SELECT 
    所属区域,
    大类,
    品类,
    COUNT(DISTINCT 存货编码) AS 商品种数,
    SUM(现存数量) AS 总库存数量,
    SUM(库存金额) AS 总库存金额,
    SUM(近90天出库数量) AS 总出库数量,
    ROUND(AVG(周转天数), 2) AS 平均周转天数,
    ROUND(AVG(年周转率), 2) AS 平均周转率,
    SUM(CASE WHEN 库存健康度 = '滞销' THEN 1 ELSE 0 END) AS 滞销商品数,
    SUM(CASE WHEN 库存健康度 = '预警' THEN 1 ELSE 0 END) AS 预警商品数
FROM TURNOVER_CALC
GROUP BY 所属区域, 大类, 品类
ORDER BY 总库存金额 DESC;
*/


-- =====================================================
-- 扩展：按品牌汇总统计
-- =====================================================
/*
SELECT 
    品牌,
    COUNT(DISTINCT 存货编码) AS 商品种数,
    SUM(现存数量) AS 总库存数量,
    SUM(库存金额) AS 总库存金额,
    SUM(近90天出库流水) AS 近90天销售额,
    ROUND(AVG(周转天数), 2) AS 平均周转天数,
    ROUND(SUM(库存金额) / NULLIF(SUM(近90天出库流水) / 90 * 365, 0), 2) AS 品牌周转率
FROM TURNOVER_CALC
GROUP BY 品牌
ORDER BY 总库存金额 DESC;
*/

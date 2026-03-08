-- =====================================================
-- 商品库存周转预警监控表
-- 用于每日监控库存异常，识别滞销、缺货、周转异常商品
-- =====================================================

WITH PARAMS AS (
    SELECT 
        TO_CHAR(SYSDATE - 30, 'YYYY-MM-DD') AS START_DATE,   -- 近30天销量分析
        TO_CHAR(SYSDATE - 1, 'YYYY-MM-DD') AS END_DATE,
        30 AS ANALYSIS_DAYS
    FROM DUAL
),

-- 商品基础信息
PRODUCT_BASE AS (
    SELECT 
        AA.PK_INVBASDOC AS 存货主键,
        AA.INVCODE AS 存货编码,
        AA.INVNAME AS 存货名称,
        AA.INVPINPAI AS 品牌,
        AA.WIDTH AS 大类,
        AA.LENGTH AS 品类,
        BB.REFSALEPRICE AS 参考售价
    FROM NC5X.BD_INVBASDOC AA
    JOIN NC5X.BD_INVMANDOC BB 
        ON AA.PK_INVBASDOC = BB.PK_INVBASDOC
    WHERE BB.SEALFLAG = 'N'
        AND LENGTH(AA.INVCODE) > 4
),

-- 当前库存
CURRENT_INV AS (
    SELECT 
        AA.CINVBASID AS 存货主键,
        SUM(AA.NONHANDNUM) AS 现存数量,
        SUM(AA.NONHANDNUM * NVL(BB.REFSALEPRICE, 0)) AS 库存金额
    FROM NC5X.IC_ONHANDNUM AA
    JOIN NC5X.BD_INVMANDOC BB 
        ON AA.CINVENTORYID = BB.PK_INVMANDOC
    WHERE AA.NONHANDNUM > 0
    GROUP BY AA.CINVBASID
),

-- 近30天销量
SALE_30D AS (
    SELECT 
        IB.CINVBASDOCID AS 存货主键,
        SUM(IB.NNUMBER) AS 销量,
        SUM(ROUND(
            (CASE 
                WHEN TO_NUMBER(IB.NNUMBER * IB.VBODYDEF5) = 0 
                THEN IB.NSUMMNY 
                ELSE IB.NNUMBER * IB.VBODYDEF5 
            END) / (IB.NTAXRATE * 0.01 + 1), 2)) AS 销售额
    FROM NC5X.SO_SALEINVOICE II
    JOIN NC5X.SO_SALEINVOICE_B IB 
        ON II.CSALEID = IB.CSALEID
    JOIN PARAMS P ON II.DBILLDATE BETWEEN P.START_DATE AND P.END_DATE
    WHERE II.DR = 0
    GROUP BY IB.CINVBASDOCID
),

-- 计算周转指标
TURNOVER_INDEX AS (
    SELECT 
        PB.*,
        NVL(CI.现存数量, 0) AS 现存数量,
        NVL(CI.库存金额, 0) AS 库存金额,
        NVL(S30.销量, 0) AS 近30天销量,
        NVL(S30.销售额, 0) AS 近30天销售额,
        
        -- 日均销量
        ROUND(NVL(S30.销量, 0) / 30, 2) AS 日均销量,
        
        -- 周转天数
        CASE 
            WHEN NVL(S30.销量, 0) = 0 THEN 999
            ELSE ROUND(NVL(CI.现存数量, 0) / (S30.销量 / 30), 0)
        END AS 周转天数,
        
        -- 可销天数
        CASE 
            WHEN NVL(S30.销量, 0) = 0 THEN 999
            ELSE ROUND(NVL(CI.现存数量, 0) / (S30.销量 / 30), 0)
        END AS 可销天数
        
    FROM PRODUCT_BASE PB
    LEFT JOIN CURRENT_INV CI ON PB.存货主键 = CI.存货主键
    LEFT JOIN SALE_30D S30 ON PB.存货主键 = S30.存货主键
    WHERE NVL(CI.现存数量, 0) > 0  -- 只显示有库存的
)

-- =====================================================
-- 预警分类输出
-- =====================================================

-- 1. 滞销预警（有库存但30天无销售）
SELECT 
    '滞销预警' AS 预警类型,
    存货编码,
    存货名称,
    品牌,
    大类,
    品类,
    现存数量,
    库存金额,
    近30天销量,
    周转天数,
    '建议清仓或调拨' AS 处理建议
FROM TURNOVER_INDEX
WHERE 近30天销量 = 0 AND 现存数量 > 0
ORDER BY 库存金额 DESC;

-- 2. 高库存预警（周转天数>90天）
SELECT 
    '高库存预警' AS 预警类型,
    存货编码,
    存货名称,
    品牌,
    大类,
    品类,
    现存数量,
    库存金额,
    近30天销量,
    周转天数,
    '建议促销或调拨' AS 处理建议
FROM TURNOVER_INDEX
WHERE 周转天数 > 90 AND 近30天销量 > 0
ORDER BY 库存金额 DESC;

-- 3. 缺货预警（库存<7天销量）
SELECT 
    '缺货预警' AS 预警类型,
    存货编码,
    存货名称,
    品牌,
    大类,
    品类,
    现存数量,
    库存金额,
    近30天销量,
    可销天数,
    ROUND(日均销量 * 15 - 现存数量, 0) AS 建议补货量,
    '建议立即补货' AS 处理建议
FROM TURNOVER_INDEX
WHERE 可销天数 < 7 AND 近30天销量 > 0
ORDER BY 近30天销售额 DESC;

-- 4. 周转健康商品（周转15-60天）
SELECT 
    '周转健康' AS 预警类型,
    存货编码,
    存货名称,
    品牌,
    大类,
    品类,
    现存数量,
    库存金额,
    近30天销量,
    周转天数,
    '保持现状' AS 处理建议
FROM TURNOVER_INDEX
WHERE 周转天数 BETWEEN 15 AND 60
ORDER BY 库存金额 DESC;

-- 5. 汇总统计
SELECT 
    '汇总统计' AS 类型,
    COUNT(DISTINCT CASE WHEN 近30天销量 = 0 AND 现存数量 > 0 THEN 存货编码 END) AS 滞销商品数,
    COUNT(DISTINCT CASE WHEN 周转天数 > 90 AND 近30天销量 > 0 THEN 存货编码 END) AS 高库存商品数,
    COUNT(DISTINCT CASE WHEN 可销天数 < 7 AND 近30天销量 > 0 THEN 存货编码 END) AS 缺货风险商品数,
    COUNT(DISTINCT CASE WHEN 周转天数 BETWEEN 15 AND 60 THEN 存货编码 END) AS 健康商品数,
    SUM(CASE WHEN 近30天销量 = 0 THEN 库存金额 ELSE 0 END) AS 滞销库存金额,
    SUM(CASE WHEN 周转天数 > 90 THEN 库存金额 ELSE 0 END) AS 高库存金额
FROM TURNOVER_INDEX;

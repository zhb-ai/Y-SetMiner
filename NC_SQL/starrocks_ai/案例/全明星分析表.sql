SELECT
  ma.*,
CASE  
WHEN ( ma.original_achievement > 0 OR ma.printer_achievement > 0 ) 
AND ma.compatible_achievement <= 0 THEN '缺少兼容合作' WHEN ma.main_drum > 0 
AND ma.brother_association > 0 
AND ma.color_drum > 0 
AND ma.black_drum > 0 
AND ma.DUPLICATE > 0 
AND ma.ribbon > 0 THEN
'A类-品类齐全' 
WHEN ma.main_drum > 0 
AND ma.brother_association > 0 
AND ma.color_drum > 0 
AND ma.black_drum > 0 THEN
'B类-主流品类齐全' 
WHEN ma.main_drum <= 0 AND ma.black_drum > 0 
AND ( ma.brother_association <= 0 AND ma.color_drum <= 0 ) THEN
'C类-重点开发' 
WHEN ma.compatible_achievement > 0and ma.main_drum > 0 
AND ma.brother_association > 0 
AND ma.color_drum <= 0 AND ma.black_drum > 0 THEN
'关注彩色扩品' 
WHEN ma.compatible_achievement > 0and ma.main_drum <= 0 
AND ma.brother_association <= 0 
AND ma.color_drum <= 0 
AND ma.black_drum <= 0 THEN
'需重新判断其价值' 
WHEN ma.DUPLICATE <= 0 THEN
'复印类扩品' ELSE '关注扩品' 
END classification_level  FROM（SELECT ma.部门1 AS department,
ma.业务员 AS sales_man,
ma.客户名称 AS customer_name,
sum( ma.主流 ) AS main_drum,
sum( ma.兄弟联想 ) brother_association,
sum( ma.彩鼓 ) color_drum,
sum( ma.黑鼓 ) black_drum,
sum( ma.碳粉 ) toner,
sum( ma.色带 ) ribbon,
sum( ma.复印类 ) DUPLICATE,
sum( ma.原装流水 ) original_achievement,
sum( ma.兼容流水 ) compatible_achievement,
sum( ma.打印机流水 ) printer_achievement 
FROM
(
SELECT
ma.部门1,
ma.业务员,
ma.客户名称,
sum(
CASE   
WHEN ma.大类 = '兼容' 
AND ma.品类 = '硒鼓' 
AND ( ma.存货名称 LIKE '%388%' OR ma.存货名称 LIKE '%2612%' ) THEN
ma.数量 ELSE 0 
END 
) AS 主流,
sum(
CASE          
WHEN ma.大类 = '兼容' 
AND ma.品类 = '硒鼓' 
AND ( ma.存货名称 LIKE '%DR%' OR ma.存货名称 LIKE '%TN%' OR ma.存货名称 LIKE '%LD%' OR ma.存货名称 LIKE '%LT%' ) THEN
ma.数量 ELSE 0 
END 
) AS 兄弟联想,
sum( CASE WHEN ma.大类 = '兼容' AND ma.品类 = '硒鼓' AND ma.小类 = '彩色' THEN ma.数量 ELSE 0 END ) 彩鼓,
sum( CASE WHEN ma.大类 = '兼容' AND ma.品类 = '硒鼓' AND ma.小类 = '黑色' THEN ma.数量 ELSE 0 END ) 黑鼓,
sum( CASE WHEN ma.大类 = '兼容' AND ma.品类 = '碳粉' THEN ma.数量 ELSE 0 END ) 碳粉,
sum( CASE WHEN ma.大类 = '兼容' AND ma.品类 LIKE '%色带%' THEN ma.数量 ELSE 0 END ) 色带,
sum( CASE WHEN ma.大类 = '兼容' AND ma.品类 LIKE '%复印%' THEN ma.数量 ELSE 0 END ) 复印类,
sum( CASE WHEN ma.大类 = '原装' THEN ma.数量 ELSE 0 END ) 原装流水,
sum( CASE WHEN ma.大类 = '打印机' THEN ma.数量 ELSE 0 END ) 打印机流水,
sum(
CASE
                
WHEN ma.大类 = '兼容' 
AND ( ma.品类 NOT IN ( '硒鼓' ) OR ma.品类 NOT LIKE '%复印%' ) THEN
ma.数量 ELSE 0 
END 
) 兼容流水
FROM
(
SELECT
-- ii.csaleid,
-- ib.pk_invbasdoc,
-- ii.VRECEIPTCODE AS 单号,
ii.dbilldate AS 日期,
substr( ii.dbilldate, 1, 7 ) AS 月份,
cu.deptname AS 市场部,
cu.n_deptname AS 部门1,
nvl(cu.psnname,'冯海霞') AS 业务员,
-- cu.pk_cumandoc 客户主键,
cu.custcode AS 客户编码,
nvl(cu.custname,'北京扬帆耐力有限公司') AS 客户名称,
-- cu.sf AS 省,
-- cu.cs AS 市,
-- II.VDEF7 AS 货运公司,
-- ii.dr,
-- m.vdef20 AS 地址,
-- yw.businame AS 业务类型,
-- ii.vnote AS 备注,
ib.nnumber AS 数量,
-- ib.nsummny AS 价税合计,
-- ib.blargessflag AS 是否赠品,
translate ( ib.invname, '#' || translate ( ib.invname, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', '#' ), '/' ) AS 型号,
translate ( ib.invname, '#' || translate ( ib.invname, '0123456789', '#' ), '/' ) AS 型号1,
ib.invcode AS 存货编码,
ib.invname AS 存货名称,
ib.length AS 品类,
ib.width AS 大类,
ib.height AS 小类,
ib.invpinpai AS 品牌
-- ck.storname AS 库房,
FROM
nc5x.so_saleinvoice ii
JOIN (
SELECT
ib.coriginalbillcode,
ib.csaleid,
ib.nnumber,
ib.nsummny,
ch.invpinpai,
ch.height,
ch.width,
ch.length,
ch.invname,
ch.invcode,
ib.blargessflag,
ch.pk_invbasdoc 
FROM
nc5x.so_saleinvoice_b ib
JOIN nc5x.bd_invbasdoc ch ON ib.cinvbasdocid = ch.pk_invbasdoc 
) ib ON ib.csaleid = ii.csaleid
LEFT JOIN nc5x.so_sale m ON ib.coriginalbillcode = m.vreceiptcode
LEFT JOIN nc5x.v_zlw_cust cu ON ii.creceiptcustomerid = cu.pk_cumandoc
LEFT JOIN nc5x.bd_busitype yw ON ii.cbiztype = yw.pk_busitype
LEFT JOIN nc5x.bd_stordoc ck ON ii.cwarehouseid = ck.pk_stordoc 
WHERE
ii.dbilldate >= to_char(TRUNC(ADD_MONTHS(TRUNC(SYSDATE,'YEAR'),-12),'YEAR'),'yyyy-mm-dd') 
and ib.width IN ( '兼容', '原装', '打印机','电脑PC' ) 
and ck.storname <> '首创虚拟库' 
and ii.dr = 0 
and cu.custname is not null
) ma 
GROUP BY
ma.部门1,
ma.业务员,
ma.客户名称,
ma.存货名称 
) ma 
GROUP BY
ma.部门1,
ma.业务员,
ma.客户名称 
ORDER BY
sum(ma.兼容流水) DESC 
) ma 

select c.*,f.合作推进,f.兼容硒鼓金额,f.兼容其他金额,f.原装合计金额 from (
SELECT
ma.客户主键,
ma.客户编码,
ma.客户名称,
ma.业务员,
ma.部门,
ma.省,
sum(JR去年总流水) JR去年总流水 ,
sum(JR去年总流水)/ 10 JR去年月均流水,
sum(YD去年总流水) YD去年总流水,
sum(YD去年总流水)/ 10 YD去年月均流水,
count( DISTINCT ma.月份 ) 交易月份数,
min( ma.月份 ) 首次交易月份,
max( ma.月份 ) 最近交易月份,
sum( JR第一月流水 ) JR第一月流水,
sum( JR第二月流水 ) JR第二月流水,
sum( JR第三月流水 ) JR第三月流水,
sum( JR当月流水 )   JR当月流水,
sum( YD第一月流水 ) YD第一月流水,
sum( YD第二月流水 ) YD第二月流水,
sum( YD第三月流水 ) YD第三月流水,
sum( YD当月流水 )   YD当月流水,
max(JR总流水) 兼容月流水峰值,
max(YD总流水) 原装打印机月流水峰值
FROM
(
SELECT
ma.客户主键,
ma.客户编码,
ma.客户名称,
ma.业务员,
ma.部门,
ma.省,
ma.月份,
sum( ma.数量 ) 数量,
sum( ma.流水 ) 流水,
sum(JR去年总流水) JR去年总流水,
sum( JR第一月流水 ) JR第一月流水,
sum( JR第二月流水 ) JR第二月流水,
sum( JR第三月流水 ) JR第三月流水,
sum( JR当月流水 ) JR当月流水,
sum( YD第一月流水 ) YD第一月流水,
sum( YD第二月流水 ) YD第二月流水,
sum( YD第三月流水 ) YD第三月流水,
sum( YD当月流水 ) YD当月流水 ,
sum(YD去年总流水) YD去年总流水,
sum(JR总流水) JR总流水,
sum(YD总流水) YD总流水
FROM
(
SELECT
substr( ma.日期, 1, 7 ) 月份,
CASE
  WHEN substr( ma.日期, 1, 7 ) >= substr( to_char ( trunc ( sysdate - 88, 'mm' ), 'yyyy-mm-dd' ), 1, 7 ) 
  AND substr( ma.日期, 1, 7 ) < substr( to_char ( trunc ( sysdate, 'mm' ), 'yyyy-mm-dd' ), 1, 7 ) THEN
    substr( ma.日期, 1, 7 ) ELSE NULL 
  END 近三月,
CASE
WHEN  ma.大类 = '兼容'and substr( ma.日期, 1, 4 ) = to_char(trunc(add_months(trunc(sysdate, 'YYYY'), -12)),'yyyy') THEN
ma.流水 ELSE 0 
END JR去年总流水,
CASE
WHEN  ma.大类 IN ( '原装', '打印机' ) and substr( ma.日期, 1, 4 ) = to_char(trunc(add_months(trunc(sysdate, 'YYYY'), -12)),'yyyy')   THEN
ma.流水 ELSE 0 
END YD去年总流水,
CASE
WHEN  ma.大类 IN ( '原装', '打印机' )  THEN
ma.流水 ELSE 0 
END YD总流水,
CASE
WHEN  ma.大类 IN ( '兼容' )  THEN
ma.流水 ELSE 0 
END JR总流水,
to_char ( add_months ( trunc ( sysdate ),- 3 ), 'yyyy-mm' ),
CASE
WHEN ma.大类 = '兼容' 
AND substr( ma.日期, 1, 7 ) = to_char ( add_months ( trunc ( sysdate ),- 3 ), 'yyyy-mm' ) THEN
ma.流水 ELSE 0 
END JR第三月流水,
CASE
      
WHEN ma.大类 = '兼容' 
AND substr( ma.日期, 1, 7 ) = to_char ( add_months ( trunc ( sysdate ),- 2 ), 'yyyy-mm' ) THEN
ma.流水 ELSE 0 
END JR第二月流水,
CASE
      
WHEN ma.大类 = '兼容' 
AND substr( ma.日期, 1, 7 ) = to_char ( add_months ( trunc ( sysdate ),- 1 ), 'yyyy-mm' ) THEN
ma.流水 ELSE 0 
END JR第一月流水,
CASE
      
WHEN ma.大类 = '兼容' 
AND substr( ma.日期, 1, 7 ) = substr( to_char ( trunc ( sysdate, 'mm' ), 'yyyy-mm-dd' ), 1, 7 ) THEN
ma.流水 ELSE 0 
END JR当月流水,
CASE
      
WHEN ma.大类 IN ( '原装', '打印机' ) 
AND substr( ma.日期, 1, 7 ) = to_char ( add_months ( trunc ( sysdate ),- 3 ), 'yyyy-mm' ) THEN
ma.流水 ELSE 0 
END YD第三月流水,
CASE
      
WHEN ma.大类 IN ( '原装', '打印机' ) 
AND substr( ma.日期, 1, 7 ) = to_char ( add_months ( trunc ( sysdate ),- 2 ), 'yyyy-mm' ) THEN
ma.流水 ELSE 0 
END YD第二月流水,
CASE WHEN ma.大类 IN ( '原装', '打印机' ) 
AND substr( ma.日期, 1, 7 ) = to_char ( add_months ( trunc ( sysdate ),- 1 ), 'yyyy-mm' ) THEN
ma.流水 ELSE 0 
END YD第一月流水,
CASE
WHEN ma.大类 IN ( '原装', '打印机' ) 
AND substr( ma.日期, 1, 7 ) = substr( to_char ( trunc ( sysdate, 'mm' ), 'yyyy-mm-dd' ), 1, 7 ) THEN
ma.流水 ELSE 0 
END YD当月流水,
ma.客户主键,
ma.客户编码,
ma.客户名称,
ma.存货编码,
ma.存货名称,
ma.大类,
ma.品类,
ma.品牌,
ma.小类,
ma.数量,
ma.是否赠品,
ma.业务类型,
ma.价税合计,
ma.流水,
ma.市场部,
ma.部门,
ma.业务员,
ma.日期,
ma.省,
ma.市,
ma.库房
FROM
(select ma.客户主键, ma.客户编码,ma.客户名称,ma.存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,(ma.价税合计/ma.数量)as 单价,ma.是否赠品,ma.业务类型,ma.价税合计,ma.流水,ma.市场部,ma.部门,ma.业务员,ma.日期,ma.省,ma.市
, substr(ma.日期,1,7) 月,ma.库房
from(
select ma.客户主键,ma.客户编码,ma.客户名称,ma.存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,ma.是否赠品,ma.业务类型,ma.价税合计,ma.流水,ma.市场部,ma.部门,ma.业务员,ma.日期,ma.省,ma.市,ma.库房
from (select 
m.daudittime 订单审批时间,
ii.daudittime 审批时间,
m.coperatorid,
ii.vreceiptcode,
ii.creceiptcustomerid as 主键,
ib.pk_invbasdoc 存货主键,
ii.VDEF9 运单号,
ib.CORIGINALBILLCODE 订单号,
m.vreceiptcode  as 外部单号,
ii.VRECEIPTCODE 发票号,
ii.dbilldate as 日期,
w.user_name as 制单人 ,
substr(ii.dbilldate,1,7) as 月份,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
cu.pk_cubasdoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
cu.sf as 省 ,
cu.cs as 市 ,
II.VDEF7 AS 货运公司,
ii.dr 删除标志 ,
yw.businame as 业务类型,
ii.vnote as 备注,
ib.nnumber as 数量,
ib.nsummny as 价税合计,
ib.noriginalcurmny as 流水,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.unitvolume*ib.nnumber as 体积,
ib.unitweight*ib.nnumber  as  重量,
ib.blargessflag  as 是否赠品,
translate( ib.invname,'#'||translate( ib.invname ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','#') ,'/')as 型号  ,
translate( ib.invname,'#'||translate( ib.invname ,'0123456789','#') ,'/')as 型号1 ,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌,
dd.storname as 库房,
m.vdef20 as 收货地址,
m.vdef8 as 服务商,
case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
from nc5x.so_saleinvoice ii
left  join (
select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode, ib.noriginalcurmny,
ch.unitvolume ,
ch.unitweight 
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc
) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu 
on ii.creceiptcorpid  = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_stordoc dd
on ii.cwarehouseid = dd.pk_stordoc
left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
left join nc5x.sm_user w
on m.coperatorid =w.cuserid
left join nc5x.bd_psndoc  us
on us.pk_psndoc= ii.cemployeeid
where (1=1)  
and length(ib.invcode) > 4 
and ii.dr = 0 
and ib.width in ('兼容','原装','打印机')
and ii.dbilldate BETWEEN to_char(trunc(add_months(trunc(sysdate, 'YYYY'), -12)),'yyyy-mm-dd') AND to_char ( sysdate, 'yyyy-mm-dd' )
) ma
) ma
) ma 
WHERE (ma.市场部 in ('北京市场部','外阜市场部','渠道部','区域销售部','平台业务部','SI业务部') or ma.业务员 in ( '刘喜丹','共享客户'))    
) ma 
GROUP BY
ma.客户主键,
ma.客户编码,
ma.客户名称,
ma.月份,
ma.业务员,
ma.部门,
ma.省
) ma
GROUP BY
ma.客户主键,
ma.客户编码,
ma.客户名称,
ma.业务员,
ma.部门,
ma.省
) c 
left join (
select 
f.合作推进,
cu.pk_cubasdoc  as customer_primary_key,
f.客户名称  as customer_name,
f.部门 as department ,
f.业务员 as sales_man ,
f.兼容硒鼓金额 ,
f.兼容其他金额 ,
f.兼容合计金额 ,
f.原装合计金额
 from nc5x.pick_up_advance f 
 LEFT join nc5x.v_zlw_cust cu
on f.客户主键 = cu.pk_cumandoc 
   ) f 
 on f.customer_primary_key = c.客户主键
 

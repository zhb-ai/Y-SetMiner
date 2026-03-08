-- 周转销量
select 
to_char(sysdate-100,'yyyy-mm-dd') 当前日期,
存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,
sum(ma.数量) 总数量 ,count(distinct ma.客户名称) as 客户数,count(ma.存货名称) as 单次,sum(近三十天销量) 近三十天销量
-- count(distinct case when 日期 between to_char(sysdate-31,'yyyy-mm-dd') and  to_char(sysdate-1,'yyyy-mm-dd') and not(日期 between '2023-01-18' and '2023-01-27') then 日期  else null end ) 实际三十天数
from (
select ii.csaleid ,
ib.pk_invbasdoc,
ii.VRECEIPTCODE,
ii.dbilldate as 日期,
substr(ii.dbilldate,1,7) as 月份,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.psnname as 业务员,
cu.pk_cumandoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
cu.sf as 省 ,
cu.cs as 市 ,
II.VDEF7 AS 货运公司,
ii.dr ,
yw.businame as 业务类型,
ii.vnote as 备注,
ib.nnumber as 数量,
case when ii.dbilldate between to_char(sysdate-31,'yyyy-mm-dd') and  to_char(sysdate-1,'yyyy-mm-dd')   then ib.nnumber  else 0 end 近三十天销量,
ib.nsummny as 价税合计,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.blargessflag  as 是否赠品,
translate( ib.invname,'#'||translate( ib.invname ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','#') ,'/')as 型号  ,
translate( ib.invname,'#'||translate( ib.invname ,'0123456789','#') ,'/')as 型号1  ,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌,
ck.storname as 库房,
case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
from nc5x.so_saleinvoice ii
join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu 
on ii.creceiptcorpid = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_stordoc ck
on ii.cwarehouseid = ck.pk_stordoc
where (ii.dbilldate between to_char(sysdate-100,'yyyy-mm-dd') and to_char(sysdate-1,'yyyy-mm-dd'))  
and not(ii.dbilldate between '2023-01-18' and '2023-01-27')
and ii.dr=0
and ib.width  in ('兼容','原装','打印机','电脑PC','智能家居')
and length(ib.invcode)>=6    
and cu.pk_cumandoc <> '0001C1100000001BZMQO'
 )ma 
group by 存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类




 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 

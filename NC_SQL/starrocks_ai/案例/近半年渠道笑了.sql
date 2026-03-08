
select 
部门  ,业务员  ,客户编码  ,客户名称  ,大类,vreceiptcode,日期
,sum(价税合计) 价税合计 ,sum(数量) 数量,count(distinct vreceiptcode ) 订单量,count(distinct 商桥订单 ) 商桥订单量,count(distinct 日期 ) 频次  from (
select 
ii.csaleid as 主键,
bd.docname as 发票销方,
bdd.docname as 订单销方,
m.creceiptcorpid,
m.vreceiptcode  ,
case when  m.VDEF16 = 'SQ' then m.vreceiptcode  else null end 商桥订单,
cuu.custname as 开票单位,
ib.pk_invbasdoc 存货主键,
ii.VRECEIPTCODE 发票号,
ii.dbilldate as 日期,
substr(ii.dbilldate,1,7) as 月份,
substr(ii.dbilldate,1,4) as 年份,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.psnname as 业务员,
cu.pk_cumandoc 客户主键,
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
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.blargessflag  as 是否赠品,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌,
ck.storname as 库房,
m.vdef20 as 收货地址,
case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
from nc5x.so_saleinvoice ii
join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc
) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu 
on ii.creceiptcorpid = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_stordoc ck
on ii.cwarehouseid = ck.pk_stordoc
left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
left join nc5x.v_zlw_cust cuu 
on m.creceiptcorpid = cuu.pk_cumandoc
left join nc5x.bd_defdoc bd 
on ii.PK_DEFDOC5 = bd.PK_DEFDOC  
left join nc5x.bd_defdoc bdd 
on m.PK_DEFDOC5 = bdd.PK_DEFDOC  
where   
length(invcode) > 5 
and ii.dr=0 
-- and  ii.dbilldate = to_char(sysdate,'yyyy-mm-dd')
-- and ii.dbilldate >= '2024-08-31'
-- and cu.sf like '%北京%'
-- and cu.deptname <> '直营+微分销'
and cu.n_deptname <> '财务部'
and cu.n_deptname like '%南京%'
-- and cu.deptname = '渠道部'
--and cu.psnname = '杨晓东'
--and cu.custname = '无锡市磊明商贸有限公司'
and  ii.dbilldate >= to_char(sysdate-181,'yyyy-mm-dd')
-- and ib.width  = '兼容'
-- and cu.custname = '欧菲斯供应链管理常熟有限公司（兼容）'
) group by 部门  ,业务员  ,客户编码  ,客户名称  ,大类,vreceiptcode,日期




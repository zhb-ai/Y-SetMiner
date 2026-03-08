
-- select 出库类型,月份,入库人,仓库,备注,sum(总销量)总销量,count(distinct 订单号) 订单量 from (
select 
bd_billtype.billtypename as 出库类型 ,
ic_general_h.daccountdate as 日期 ,
substr(ic_general_h.daccountdate,1,7) 月份,
w.user_name as 制单人 ,
ic_general_h.vbillcode as 订单号 ,
ic_general_h.VUSERDEF19 as 入库人,
ic_general_h.VNOTE as 备注,
c.invcode as 存货编码 ,
c.invname  as 存货名称 ,
bd_stordoc.storname 仓库 ,
lc.storname 对应仓,
c.width    as 大类 ,
c.length    as 品类 ,
sum(case when c.length = '硒鼓' then nvl(ic_general_b.noutnum, 0)+nvl(ic_general_b.ninnum, 0) else 0 end ) 硒鼓数量,
sum(c.unitvolume * nvl(nvl(ic_general_b.noutnum, ic_general_b.ninnum),0)) as 体积,
sum(c.unitweight * nvl(nvl(ic_general_b.noutnum, ic_general_b.ninnum),0) )  as  重量,
sum(nvl(ic_general_b.noutnum, 0)) + sum(nvl(ic_general_b.ninnum, 0)) 数量
from nc5x.ic_general_h
inner  join  nc5x.ic_general_b
on ic_general_h.cgeneralhid = ic_general_b.cgeneralhid and
ic_general_b.dr = 0 and ic_general_h.fbillflag >= 3
inner join  nc5x.bd_invbasdoc  c 
on (ic_general_b.cinvbasid = c.pk_invbasdoc)
inner join  nc5x.bd_billtype
on (ic_general_h.cbilltypecode = bd_billtype.pk_billtypecode)
left outer join  nc5x.bd_stordoc
on (ic_general_h.cwarehouseid = bd_stordoc.pk_stordoc)
left join nc5x.sm_user w
on ic_general_h.coperatorid  =w.cuserid
left outer join  nc5x.bd_stordoc lc
on (ic_general_h.cotherwhid = lc.pk_stordoc)
 

where  daccountdate between '2024-06-01' and '2024-12-125'and ic_general_b.dr = 0 
and (bd_billtype.billtypename like '%调拨出库%')  
and length(c.invcode)> 4
and c.width in ('兼容') 
and bd_stordoc.storname = '北京仓'
-- and  bd_stordoc.storname like '%寄售%'
-- and not ( c.invname  like '%折扣%' or invname  like '%运费%' )
-- and bd_billtype.billtypename  like '%调拨%'
-- and c.width in ('兼容')  and  c.invcode = 'AF0017' 
-- and ic_general_h.vbillcode = 'DC2208300003'
group by 
bd_billtype.billtypename,
ic_general_h.daccountdate,
bd_stordoc.storname,
ic_general_h.vbillcode,
w.user_name,
c.invcode,
c.invname,
c.width ,
c.length,
ic_general_h.VUSERDEF19,
ic_general_h.VNOTE,
lc.storname 

-- ) group by 出库类型,月份,入库人,仓库,备注

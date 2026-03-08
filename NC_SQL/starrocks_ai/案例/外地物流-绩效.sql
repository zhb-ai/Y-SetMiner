select 
bd_billtype.billtypename as 出库类型 ,
ic_general_h.dbilldate as 日期 ,
substr(ic_general_h.dbilldate,1,7) 月份,
w.user_name as 制单人 ,
ic_general_h.vbillcode as 订单号 ,
daccountdate ,
dbilldate,
ic_general_h.VUSERDEF19 as 入库人,
ic_general_h.VNOTE as 备注,
c.invcode as 存货编码 ,
c.invname  as 存货名称 ,
bd_stordoc.storname 仓库 ,
ck.storname 对应仓库,
c.width    as 大类 ,
c.length    as 品类 ,
sum(case when c.length = '硒鼓' then nvl(ic_general_b.noutnum, 0)+nvl(ic_general_b.ninnum, 0) else 0 end ) 硒鼓数量,
sum(c.unitvolume * nvl(nvl(ic_general_b.noutnum, ic_general_b.ninnum),0)) as 体积,
sum(c.unitweight * nvl(nvl(ic_general_b.noutnum, ic_general_b.ninnum),0) )  as  重量,
sum(nvl(ic_general_b.noutnum, 0)) + sum(nvl(ic_general_b.ninnum, 0)) 总数量
-- sum(case when c.unitvolume >0 and c.unitweight > 0 then nvl(ic_general_b.noutnum, 0) + nvl(ic_general_b.ninnum, 0) else 0 end ) as 数量
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
left outer join  nc5x.bd_stordoc ck
on (ic_general_h.cotherwhid  = ck.pk_stordoc)
left join nc5x.sm_user w
on ic_general_h.coperatorid  =w.cuserid
where daccountdate between '2025-09-01' and '2025-09-30'and ic_general_b.dr = 0 
-- and (bd_billtype.billtypename like '%入库%')  
-- and length(c.invcode)> 4
-- and c.width NOT  in ('原装','兼容','打印机','智能家居','电脑PC')
and not ( c.invname  like '%折扣%' or invname  like '%运费%' )
-- and bd_stordoc.storname in ('哈尔滨仓','沈阳仓','西安仓','成都仓','重庆仓')
-- and bd_stordoc.storname in ('南京仓')
and ((bd_stordoc.storname in ('南京仓','哈尔滨仓','沈阳仓','西安仓','成都仓','重庆仓','仁和云仓中山库','中山慧采仓','京东pop仁和-云仓-中山仓','中山兼容仓','京东慧采大智-中山云仓','京东慧采耐力-中山云仓','中山国补仓'))
or  bd_stordoc.storname like '%中山%')
 --and bd_stordoc.storname like '%中山%'
-- and bd_stordoc.storname in ('仁和云仓中山库','中山慧采仓','京东pop仁和-云仓-中山仓')
-- and bd_billtype.billtypename  like '%调拨%'
-- and c.width in ('兼容')  and  c.invcode = 'AF0017' 
-- and ic_general_h.vbillcode = 'DC2311130002'
group by 
bd_billtype.billtypename,
ic_general_h.dbilldate,
bd_stordoc.storname,
ck.storname,
ic_general_h.vbillcode,
w.user_name,
c.invcode,
c.invname,
c.width ,
c.length,
ic_general_h.VUSERDEF19,
ic_general_h.VNOTE,
daccountdate ,
dbilldate






select 出库仓库,年份,count(distinct 订单号) 订单量,sum(硒鼓数量)硒鼓数量,sum(总销量) 总销量  from (
select 
bd_billtype.billtypename as 出库类型 ,
ic_general_h.dbilldate as 日期 ,
substr(ic_general_h.dbilldate,1,4) 年份,
w.user_name as 制单人 ,
ic_general_h.vbillcode as 订单号 ,
ic_general_h.VUSERDEF19 as 入库人,
ic_general_h.VNOTE as 备注,
c.invcode as 存货编码 ,
c.invname  as 存货名称 ,
bd_stordoc.storname 出库仓库 ,
rk.storname 入库仓库,
c.width    as 大类 ,
c.length    as 品类 ,
c.invpinpai as 品牌,
c.unitvolume,
c.unitweight,
sum(case when c.length = '硒鼓' then nvl(ic_general_b.noutnum, 0)+nvl(ic_general_b.ninnum, 0) else 0 end ) 硒鼓数量,
sum(c.unitvolume * nvl(nvl(ic_general_b.noutnum, ic_general_b.ninnum),0)) as 体积,
sum(c.unitweight * nvl(nvl(ic_general_b.noutnum, ic_general_b.ninnum),0) )  as  重量,
sum(nvl(ic_general_b.noutnum, 0)) + sum(nvl(ic_general_b.ninnum, 0)) 总销量,
sum(case when c.unitvolume >0 and c.unitweight > 0 then nvl(ic_general_b.noutnum, 0) + nvl(ic_general_b.ninnum, 0) else 0 end ) as 数量
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
left outer join  nc5x.bd_stordoc  rk
on (ic_general_h.cotherwhid  = rk.pk_stordoc)
left join nc5x.sm_user w
on ic_general_h.coperatorid  =w.cuserid
where 
-- dbilldate between '2023-10-01' and '2023-12-31'
dbilldate >= to_char(sysdate-91,'yyyy-mm-dd')
and ic_general_b.dr = 0 
-- and length(c.invcode)>=5
-- and c.width in ('兼容')
-- and bd_stordoc.storname = '南京仓'
-- and c.invpinpai in ('华为','奔图','惠普')
-- and bd_stordoc.storname = '1号库'
-- and rk.storname in ('哈尔滨本部','沈阳本部','南京本部','西安本部','成都本部','重庆本部')
and bd_billtype.billtypename  like '%销售出库%'
-- and bd_stordoc.storname in ('北京仓','南京仓','沈阳仓')
-- and c.width in ('兼容')  and  c.invcode = 'AF0017' 
-- and ic_general_h.vbillcode = 'XC2207281404'
group by 
bd_billtype.billtypename,
ic_general_h.dbilldate,
bd_stordoc.storname,
rk.storname,
ic_general_h.vbillcode,
w.user_name,
c.invcode,
c.invname,
c.width ,
c.length,
ic_general_h.VUSERDEF19,
ic_general_h.VNOTE,
c.unitvolume,
c.unitweight,
c.invpinpai



union all 
select 出库类型,订单号,日期,sum(硒鼓数量)硒鼓数量, sum(数量)数量  from (
 select 
'销售订单' as 出库类型,
ii.dbilldate as 日期,
ib.CORIGINALBILLCODE 订单号,
ib.nnumber as 数量,
case when ib.length = '硒鼓' then ib.nnumber else 0 end 硒鼓数量
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
where 
length(ib.invcode) > 4 
and ii.dr = 0 
and ib.width in ('兼容','原装','打印机')
and ii.dbilldate >= '2022-08-01'
and ii.dbilldate <= '2022-08-31'
and cu.deptname = '直营+微分销'
and ib.CORIGINALBILLCODE  = '246130251345'
 ) 
group by 出库类型,日期,订单号

select * 
from nc5x.ic_general_h
inner  join  nc5x.ic_general_b on ic_general_h.cgeneralhid = ic_general_b.cgeneralhid and
ic_general_b.dr = 0 and ic_general_h.fbillflag >= 3 where ic_general_h.vbillcode = 'DC2209010001'

select storname,pk_stordoc   from nc5x.bd_stordoc where storname = '1号库'

select 
存货编码,日期,仓库 ,订单号,sum(入库量)入库量 from (
select case when storcode in ('052','051') then '成都仓'
when storcode in ('013','005') then '科贸3A003'
when storcode in ('017','019') then '沈阳仓'
when storcode in ('084','150','001') then '北京仓'
when storcode in ('022','092') then '南京仓'
when storcode in ('076','145') then '中山仓'
else storname end 仓库,
ic_general_b.cgeneralbid,
ic_general_h.daccountdate as 日期 ,
ic_general_h.vbillcode as 订单号 ,
ic_general_h.VNOTE as 备注,
c.invcode as 存货编码 ,
c.invname  as 存货名称 ,
nvl(ic_general_b.ninnum, 0) + nvl(ic_general_b.noutnum, 0) as 入库量
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
where  
daccountdate >= to_char(sysdate-7,'yyyy-mm-dd') 
and ic_general_b.dr = 0 
and (bd_billtype.billtypename like '%采购入库%') 
and length(c.invcode)> 4 
and c.width = '兼容'
and  storcode in ('058','056','043','017','019','084','022','005','013','092','150','020','051','052','001','076','145')
) ma 
group by  存货编码,日期,仓库,订单号  




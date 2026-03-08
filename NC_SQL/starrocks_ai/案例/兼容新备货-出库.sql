select 存货编码,存货名称,仓库,sum(数量) 九十天出库数量,count(distinct 客户) 九十天出库客户数,max(数量) 九十天最大出库数量,sum(三十天出库数量)三十天出库数量,
count(distinct 三十天出库客户) 三十天出库客户数,
max(三十天出库数量)三十天最大出库数量
from (
select 
c.invcode as 存货编码 ,
c.invname  as 存货名称 ,
sum(nvl(ic_general_b.noutnum, 0)) 数量,
pk_cubasdocc as 客户,
case when dbilldate >=  to_char(sysdate-31,'yyyy-mm-dd') then pk_cubasdocc else null end 三十天出库客户,
case when dbilldate >=  to_char(sysdate-31,'yyyy-mm-dd') then sum(nvl(ic_general_b.noutnum, 0)) else 0 end 三十天出库数量,
dbilldate as 日期,
bd_stordoc.storname ,
case when bd_stordoc.storcode in ('052','051') then '成都仓'
when bd_stordoc.storcode in ('013','005') then '科贸3A003'
when bd_stordoc.storcode in ('017','019') then '沈阳仓'
else bd_stordoc.storname end 仓库,
vbillcode
from nc5x.ic_general_h
inner  join  nc5x.ic_general_b
on ic_general_h.cgeneralhid = ic_general_b.cgeneralhid and
ic_general_b.dr = 0 and ic_general_h.fbillflag >= 3
inner join  nc5x.bd_invbasdoc  c 
on (ic_general_b.cinvbasid = c.pk_invbasdoc)
left outer join  nc5x.bd_stordoc
on (ic_general_h.cwarehouseid = bd_stordoc.pk_stordoc)
left join nc5x.sm_user w
on ic_general_h.coperatorid  =w.cuserid
where  
dbilldate >=  to_char(sysdate-91,'yyyy-mm-dd') 
-- dbilldate between '2023-03-14' and '2023-03-14'
and ic_general_b.dr = 0 
and cbilltypecode = '4C'
and length(c.invcode)> 4
and c.width in ('兼容')
and bd_stordoc.storcode in ('001',
'022','017','056','020','051','076','058','065','084','069','150','019',
'092','043','067','013','005','068','080',
'078','052','072','090','089','091','074','073','079','070')
-- and bd_stordoc.storcode in ('001','051','056','020','017','022','058')
group by 
c.invcode, 
c.invname,
bd_stordoc.storname,
bd_stordoc.storcode,
dbilldate,
pk_cubasdocc,
vbillcode) group by 存货编码,存货名称,仓库
















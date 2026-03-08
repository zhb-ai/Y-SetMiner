
select
nvl(m.存货编码,j.存货编码) || nvl(m.仓库,j.仓库)  as RK,
 nvl(m.存货编码,j.存货编码) invcode,nvl(m.存货名称,j.存货名称) invname,nvl(m.仓库,j.仓库) storname ,m.六十天出库数量 as sixty_out_num ,m.六十天最大出库数量 as sixty_out_max ,三十天出库数量 as thirty_out_num 
,三十天最大出库数量 as thirty_out_max ,结存数量 as nonhandnum from (
select 存货编码,存货名称,仓库,sum(数量) 六十天出库数量,max(数量) 六十天最大出库数量,sum(三十天出库数量)三十天出库数量,
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
bd_stordoc.storname 仓库,
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
dbilldate >=  to_char(sysdate-61,'yyyy-mm-dd') 
-- dbilldate between '2023-03-14' and '2023-03-14'
and ic_general_b.dr = 0 
and cbilltypecode = '4C'
and length(c.invcode)> 4
and c.width in ('兼容','原装','打印机','电脑PC','智能家居')
and (bd_stordoc.storname like '%京东pop%' or bd_stordoc.storname like '%天猫%')
-- and bd_stordoc.storcode in ('001','022','017','056','020','051','076','058','065','084','069','150','019','092','043','067','013','005','068','080','078','052','072','090','089','091','074','073','079','070')
group by 
c.invcode, 
c.invname,
bd_stordoc.storname,
bd_stordoc.storcode,
dbilldate,
pk_cubasdocc,
vbillcode) group by 存货编码,存货名称,仓库) m 
full join (
select 存货编码,存货名称,仓库,sum(结存数量)结存数量 from (
select
bb.invcode 存货编码,
bb.invname 存货名称,
SUM(dd.nonhandnum) 结存数量 ,
dd.storname 仓库,
dd.storcode,
dd.pk_stordoc
from nc5x.bd_invbasdoc bb
left join ( select aa.cinvbasid , aa.cwarehouseid, aa.nonhandnum,cc.pk_stordoc,cc.storname,cc.storcode
      from nc5x.ic_onhandnum aa
      join nc5x.bd_stordoc cc
      on aa.cwarehouseid = cc.pk_stordoc where cc.dr =0  ) dd
on dd.cinvbasid = bb.pk_invbasdoc
where 
(dd.storname like '%京东pop%' or dd.storname like '%天猫%')
and dd.nonhandnum <> 0 
GROUP BY bb.invcode ,dd.storname, dd.storcode,dd.pk_stordoc,bb.invname ) 
group by 存货编码,存货名称,仓库) j
on m.存货编码 = j.存货编码 and  m.仓库 = j.仓库 












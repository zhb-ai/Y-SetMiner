select * from (
select 
bd_billtype.billtypename,
c.invcode as 存货编码 ,
c.invname  as 存货名称 ,
bd_stordoc.storname 仓库 ,
bd_stordoc.storcode ,
c.width    as 大类 ,
c.length    as 品类 ,
c.invpinpai   as 品牌 ,
c.height as 小类 ,
dbilldate,
sum(nvl(ic_general_b.noutnum, 0)) + sum(nvl(ic_general_b.ninnum, 0)) 入库数量
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
--  dbilldate = to_char(sysdate,'yyyy-mm-dd') 
dbilldate between '2022-03-14' and '2023-03-14'
and ic_general_b.dr = 0 
and (bd_billtype.billtypename like '%入库%')  
and length(c.invcode)> 4
and c.width in ('兼容')
and c.length like '%色带%'
and bd_stordoc.storcode in ('020')
-- and bd_stordoc.storcode in ('001','051','056','020','017','0 22','058')
group by 
c.invcode, 
c.invname,
bd_stordoc.storname,
bd_stordoc.storcode,
c.width,
c.length,
c.invpinpai,
c.height ,
dbilldate,
bd_billtype.billtypename
)  rk 
left join (
select
bb.invcode 存货编码,
SUM(dd.nonhandnum) 结存数量 ,
dd.storname ,
dd.storcode
from nc5x.bd_invbasdoc bb
left join ( select aa.cinvbasid , aa.cwarehouseid, aa.nonhandnum,cc.pk_stordoc,cc.storname,cc.storcode
      from nc5x.ic_onhandnum aa
      join nc5x.bd_stordoc cc
      on aa.cwarehouseid = cc.pk_stordoc where cc.dr =0  ) dd
on dd.cinvbasid = bb.pk_invbasdoc
where dd.storcode in ('020') 
GROUP BY bb.invcode ,dd.storname, dd.storcode
) xc 
on rk.存货编码 = xc.存货编码 and rk.storcode = xc.storcode --  where xc.结存数量 =  0 






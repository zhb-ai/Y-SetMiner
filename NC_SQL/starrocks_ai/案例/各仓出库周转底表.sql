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
dbilldate >= to_char(sysdate-91,'yyyy-mm-dd') 
-- dbilldate between '2022-03-14' and '2023-03-14'
and ic_general_b.dr = 0 
and (bd_billtype.billtypename like '%销售出库%')  
and length(c.invcode)> 4
-- and bd_stordoc.storcode in ('020')
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
bd_billtype.billtypename


/*库存+金额*/
select
dd.storname   库房,
bb.invcode   存货编码,
bb.invname   存货名称,
bb.width   大类,
bb.invpinpai   品牌,
bb.length   品类,
bb.height   小类,
dd.nonhandnum   结存数量,
case when gg.nabprice is NUll then (case when gg.noutnum = 0 then 0 else round(gg.noutmny/gg.noutnum,2)end) else gg.nabprice  end 金额,
nvl(dd.nonhandnum*(case when gg.nabprice is NUll then (case when gg.noutnum = 0 then 0 else round(gg.noutmny/gg.noutnum,2)end) else gg.nabprice  end),0)   库存金额
from nc5x.bd_invbasdoc bb
join (select aa.cinvbasid , aa.cwarehouseid, aa.nonhandnum,cc.pk_stordoc , cc.storname
      from nc5x.ic_onhandnum aa
      join nc5x.bd_stordoc cc
      on aa.cwarehouseid = cc.pk_stordoc) dd
on dd.cinvbasid = bb.pk_invbasdoc
join (select ee.pk_invmandoc , ff.cinventoryid ,ee.pk_invbasdoc,ff.nabprice，ff.caccountmonth,ff.noutmny,ff.noutnum
      from nc5x.bd_invmandoc ee
      join nc5x.ia_generalledger ff
      on ee.pk_invmandoc=ff.cinventoryid  and ff.dr=0) gg
on gg.pk_invbasdoc=bb.pk_invbasdoc
where dd.nonhandnum<>0
and gg.caccountmonth<>'00'
and substr(bb.invcode,1,2) <>'98'
---and bb.width <> 'null'
---and bb.invpinpai <> 'null'
----and dd.storname in ()

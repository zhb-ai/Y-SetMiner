select
dd.storname   库房,
bb.pk_invbasdoc  主键,
bb.invcode   存货编码,
bb.invname   存货名称,
bb.width   大类,
bb.invpinpai   品牌,
bb.length   品类,
bb.height   小类,
gg.nabprice,
dd.nonhandnum   结存数量,
--case when gg.nabprice<>NUll then gg.nabprice else (case when gg.noutnum = 0 then 0 else round(gg.noutmny/gg.noutnum,2)end) end  金额,
nvl(dd.nonhandnum*(case when gg.nabprice is NUll then (case when gg.noutnum = 0 then 0 else round(gg.noutmny/gg.noutnum,2)end) else gg.nabprice end),0 ) 库存金额
from nc5x.bd_invbasdoc bb
join (select aa.cinvbasid , aa.cwarehouseid, aa.nonhandnum,cc.pk_stordoc , cc.storname
      from nc5x.ic_onhandnum aa
      join nc5x.bd_stordoc cc
      on aa.cwarehouseid = cc.pk_stordoc) dd
on dd.cinvbasid = bb.pk_invbasdoc
join (select ee.pk_invmandoc , ff.cinventoryid ,ee.pk_invbasdoc,ff.nabprice，ff.caccountmonth,ff.noutmny,ff.noutnum
      from nc5x.bd_invmandoc ee
      join nc5x.ia_generalledger ff
      on ee.pk_invmandoc=ff.cinventoryid ) gg
on gg.pk_invbasdoc=bb.pk_invbasdoc
where dd.nonhandnum<>0
and gg.caccountmonth<>'0'
and bb.width <> 'null'
and bb.width in ('兼容')
and bb.invpinpai <> 'null'

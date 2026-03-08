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

select distinct d.* from (select m.* ,js.dmakedate 制单日期,js.单价 as 成本, m.数量*js.单价 金额
from
(select d.出仓仓库,d.存货编码,d.日期 ,sum(d.数量) 数量 from  (select
rc.storname 入仓仓库,
cc.storname 出仓仓库,
ch.invcode 存货编码,
ch.invname 存货名称,
ch.width 大类,
db.nnum 数量,
zb.dauditdate 日期,
zb.user_name ,
db.vcode 单号
 from nc5x.to_bill_b db
join nc5x.Bd_Stordoc rc
  on db.cinwhid= rc.pk_stordoc
join nc5x.Bd_Stordoc cc
  on db.coutwhid= cc.pk_stordoc
join nc5x.bd_invbasdoc ch
  on db.cinvbasid= ch.pk_invbasdoc
join (select  zb.coperatorid,zb.cbillid,us.user_name,us.cuserid,zb.dauditdate
       from nc5x.to_bill zb
       join nc5x.sm_user us
         on zb.coperatorid = us.cuserid and zb.dr=0)zb
  on zb.cbillid = db.cbillid
  and db.dr=0
where zb.dauditdate between '2020-02-01'and '2020-03-31'
 --zb.dauditdate = to_char(TRUNC(sysdate-7),'yyyy-mm-dd')
 and cc.storname='科捷仓-北京朝阳'
and db.vcode  like '%A%')d group by d.出仓仓库,d.存货编码,d.日期)m

 join nc5x.bd_invbasdoc aa on m.存货编码=aa.invcode
join nc5x.bd_invmandoc bb
on aa.pk_invbasdoc = bb.pk_invbasdoc
join (select d.* ,d.ncostmny/d.nnewbalancenum 单价 from  nc5x.so_squaredetail d  ) js
on  js.cinventoryid = bb.pk_invmandoc and js.dmakedate=m.日期 
)d
---and zb.user_name = '1号库NC专员'

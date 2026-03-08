/*调拨单*/
select sum(ma.数量) from 
(

select 
rc.storname as 入库仓库,
cc.storname as 出库仓库,
cg.invcode as 存货编码,                                                                                                                                                                      
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
db.nnum 数量,
zb.dbilldate 日期,
zb.user_name 操作人,
to_char(to_date(zb.tlastmodifytime,'yyyy-mm-dd hh24:mi:ss'),'hh24:mi:ss'),
--case when zb.tlastmodifytime is not null  then to_char(zb.tlastmodifytime,'hh24:mi:ss') else ''end 时间,
cd.单价,
db.vnote,
db.vcode
 from nc5x.to_bill_b db
join nc5x.Bd_Stordoc rc
  on db.cinwhid= rc.pk_stordoc
join nc5x.Bd_Stordoc cc
  on db.coutwhid= cc.pk_stordoc
join (select  zb.coperatorid,zb.cbillid,us.user_name,us.cuserid,zb.dbilldate,zb.tlastmodifytime
       from nc5x.to_bill zb
       join nc5x.sm_user us
         on zb.coperatorid = us.cuserid and zb.dr=0)zb
  on zb.cbillid = db.cbillid 
   left join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,cg.pk_invbasdoc
from nc5x.bd_invmandoc cg
join nc5x.bd_invbasdoc ch
on cg.pk_invbasdoc = ch.pk_invbasdoc)cg
on db.cinvbasid= cg.pk_invbasdoc 
 left join (select cinventoryid ,max(nabprice) as 单价 from nc5x.ia_generalledger cd group by cinventoryid)cd 
on cd.cinventoryid = cg.pk_invmandoc
where zb.dbilldate >= '2020-11-01'
and zb.dbilldate<= '2020-11-31'
and cc.storname='1号库'
and db.dr=0 
and zb.user_name = '于春宇'
--AND cg.width ='兼容'
--and cg.length  ='硒鼓'
) ma

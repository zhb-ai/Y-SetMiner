
select 
da.调出仓库 dc_warehouse,
da.调入仓库 dr_warehouse,
da.大类 the_class,
da.日期 the_date,
sum(总金额) turnover 
from (
select 
case when rc.storcode in ('001','005','013','316','043','084','099','016','065','086','087','326','070','080','067','1002','004','116','04301','06501','071') then '北京仓' 
when rc.storcode in ('022','069','02202','073','074','078','068','085','02201') then '南京仓' when rc.storcode in ('017','019','346','01701') then '沈阳仓' 
when rc.storcode in ('051','052') then '成都仓' when rc.storcode in ('056','057','05601') then '西安仓' when rc.storcode in ('020') then '哈尔滨仓' 
when rc.storcode in ('058','05801') then '重庆仓' when rc.storcode in ('076','145') then '中山仓' 
else '其他' end 调入仓库,
case when cc.storcode in ('001','005','013','316','043','084','099','016','065','086','087','326','070','080','067','1002','004','116','04301','06501','071') then '北京仓' 
when cc.storcode in ('022','069','02202','073','074','078','068','085','02201') then '南京仓' when cc.storcode in ('017','019','346','01701') then '沈阳仓' 
when cc.storcode in ('051','052') then '成都仓' when cc.storcode in ('056','057','05601') then '西安仓' when cc.storcode in ('020') then '哈尔滨仓' 
when cc.storcode in ('058','05801') then '重庆仓' when cc.storcode in ('076','145') then '中山仓'
else '其他' end 调出仓库,
ch.invname 产品名称,
ch.invcode 产品,
gp.width 大类,
gp.nabprice,
db.noutsumnum  申请上已调出数量 ,
gp.nabprice * db.noutsumnum 总金额,
zb.dbilldate 日期 
from nc5x.to_bill_b db join nc5x.Bd_Stordoc rc on db.cinwhid= rc.pk_stordoc 
join nc5x.Bd_Stordoc cc on db.coutwhid= cc.pk_stordoc 
join nc5x.bd_invbasdoc ch on db.cinvbasid= ch.pk_invbasdoc 
join (
select  zb.coperatorid,zb.cbillid,us.user_name,us.cuserid,zb.dbilldate from nc5x.to_bill zb join nc5x.sm_user us on zb.coperatorid = us.cuserid and zb.dr=0)zb 
on zb.cbillid = db.cbillid and db.dr=0 
left join (
select 
bb.invcode,bb.invname,bb.width,bb.invpinpai,bb.length,bb.height,
case when gg.nabprice is NUll then (case when gg.noutnum = 0 then 0 else round(gg.noutmny/gg.noutnum,2)end) else gg.nabprice  end nabprice,
gg.cinventoryid  主键 
from nc5x.bd_invbasdoc bb 
join (
select ee.pk_invmandoc , ff.cinventoryid ,ee.pk_invbasdoc,ff.nabprice,ff.caccountmonth,ff.noutmny,ff.noutnum 
from nc5x.bd_invmandoc ee 
join nc5x.ia_generalledger ff 
on ee.pk_invmandoc=ff.cinventoryid and ff.dr=0 where ee.dr = 0 and ff.dr = 0
) gg 
on gg.pk_invbasdoc=bb.pk_invbasdoc 
where bb.width in ('原装','打印机','兼容') and gg.caccountmonth<> '00' and bb.dr = 0
) gp on ch.invcode = gp.invcode where db.vcode like '%A%' and gp.width is not null and zb.dbilldate >= to_char(TRUNC(sysdate-31),'yyyy-mm-dd') 
and zb.dbilldate <= to_char(TRUNC(sysdate-1),'yyyy-mm-dd') 
and db.noutsumnum is not null
) da group by da.调出仓库,da.调入仓库,da.大类,da.日期 order by da.调出仓库,da.调入仓库,da.大类,da.日期

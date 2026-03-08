
select d.入仓仓库,d.存货编码,sum(d.数量) from  (
select 
 REGEXP_REPLACE(rc.storname,'( ){1,}', '') 入仓仓库,
 REGEXP_REPLACE(cc.storname,'( ){1,}', '') 出仓仓库,
ch.invcode 存货编码,
ch.invname 存货名称,
ch.width 大类,
db.nnum 数量,
zb.dauditdate 日期,
zb.user_name 制单人,
db.vcode 单号
 from nc5x.to_bill_b db
join nc5x.Bd_Stordoc rc
  on db.cinwhid= rc.pk_stordoc
join nc5x.Bd_Stordoc cc
  on db.coutwhid= cc.pk_stordoc
join nc5x.bd_invbasdoc ch
  on db.cinvbasid= ch.pk_invbasdoc
join (select  zb.cincorpid,zb.coperatorid,zb.cbillid,us.user_name,us.cuserid,zb.dauditdate 
       from nc5x.to_bill zb
       join nc5x.sm_user us
         on zb.coperatorid = us.cuserid and zb.dr=0)zb
  on zb.cbillid = db.cbillid 
where
  cc.storname in ('1号库')
  and zb.dauditdate between  '2021-11-01'and '2021-12-31'

)d group by d.入仓仓库,d.存货编码 order by sum(d.数量) desc 

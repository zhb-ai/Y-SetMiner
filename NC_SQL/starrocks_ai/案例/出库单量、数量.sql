select d.出仓仓库,d.单号,count(distinct(d.单号)) over(partition by d.单号）,sum(d.数量) 数量 from  (select 
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
where zb.dauditdate between '2020-06-01' and  '2020-06-30'--and to_char(SYSDATE,'yyyy-mm-dd')
and db.vcode  like '%A%'and substr(REGEXP_REPLACE(rc.storname,'( ){1,}', ''),1,2)<>substr(REGEXP_REPLACE(cc.storname,'( ){1,}', '') ,1,2)--and ch.invcode='GA0112'
  --and db.vcode='5A2003190021'
)d     group by d.出仓仓库,d.单号 order by sum(d.数量)


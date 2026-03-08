select m.*,d.length 品类 ,d.height 小类,d.def10 as 供应商,
d.def2 as 装箱数   from (select d.入仓仓库,d.存货编码 ,d.存货名称,sum(d.数量)数量, dense_rank()OVER(PARTITION BY d.入仓仓库
        ORDER BY  sum(d.数量) desc ) AS 排名 from  (select 
rc.storname 入仓仓库,
cc.storname 出仓仓库,
ch.invcode 存货编码,
ch.invname 存货名称,
ch.width 大类,
db.nnum 数量,
ch.length 品类,
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
join (select  zb.coperatorid,zb.cbillid,us.user_name,us.cuserid,zb.dauditdate 
       from nc5x.to_bill zb
       join nc5x.sm_user us
         on zb.coperatorid = us.cuserid and zb.dr=0)zb
  on zb.cbillid = db.cbillid 
where zb.dauditdate between '2020-03-01' and substr(to_char(SYSDATE-1,'yyyy-mm-dd'),1,7) and db.vcode like '%A%' 
and substr(REGEXP_REPLACE(rc.storname,'( ){1,}', ''),1,2)<>substr(REGEXP_REPLACE(cc.storname,'( ){1,}', '') ,1,2) and ( ch.length like  ('%色带%')or ch.length like  ('%鼓%') or ch.length like  ('%碳%') ) and rc.storname in ('成都本部',
'哈尔滨本部',
'科捷仓-北京朝阳',                              
'南京本部',
'沈阳东贸库',
'西安本部',
'重庆本部') 
and  ch.width not in ('原装')
--zb.dauditdate . to_char(TRUNC(sysdate-7),'yyyy-mm-dd') 
 --and cc.storname='科捷仓-北京朝阳'
 )d group by d.入仓仓库,d.存货编码,d.存货名称 order by d.入仓仓库, 排名  asc  ) m left join nc5x.bd_invbasdoc d on m.存货编码=d.invcode 

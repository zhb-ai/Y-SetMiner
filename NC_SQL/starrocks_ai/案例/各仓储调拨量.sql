
select d.出仓仓库,d.存货编码,d.日期 ,sum(d.数量) 数量,dense_rank()OVER(PARTITION BY d.出仓仓库,d.存货编码
        ORDER BY sum(d.数量) desc ) AS 排名 from  (
select 
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
where zb.dauditdate between '2020-03-01'and   substr(to_char(SYSDATE-1,'yyyy-mm-dd'),1,7)
 --zb.dauditdate = to_char(TRUNC(sysdate-7),'yyyy-mm-dd') 
 --and cc.storname='科捷仓-北京朝阳'
 and db.vcode  like '%A%' ) d
  group by d.出仓仓库,d.存货编码,d.日期
  
  
---and zb.user_name = '1号库NC专员'

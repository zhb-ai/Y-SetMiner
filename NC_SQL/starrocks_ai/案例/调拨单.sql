select 
vfirstcode,
rc.storname 入仓仓库,
cc.storname 出仓仓库,
ch.invcode 存货编码,
ch.invname 存货名称,
ch.width 大类,
--ch.length ,
--ch.height,
db.nnum 调拨预计数量 ,
db.noutsumnum 调拨数量 ,
case when  rc.storname ='南京本部'and  zb.dbilldate >= to_char(sysdate - 4,'yyyy-mm-dd') then  db.noutsumnum else 0 end 南京调拨数量,
  case when  rc.storname ='西安本部'and  zb.dbilldate >= to_char(sysdate - 5,'yyyy-mm-dd') then  db.noutsumnum else 0 end 西安调拨数量,
    case when  rc.storname ='成都本部'and  zb.dbilldate > =to_char(sysdate - 10,'yyyy-mm-dd') then  db.noutsumnum else 0 end 成都调拨数量,
      case when  rc.storname ='重庆本部'and  zb.dbilldate >= to_char(sysdate - 11,'yyyy-mm-dd') then  db.noutsumnum else 0 end 重庆调拨数量,
        case when  rc.storname ='哈尔滨本部'and  zb.dbilldate >= to_char(sysdate - 5,'yyyy-mm-dd') then  db.noutsumnum else 0 end 哈尔滨调拨数量,
          case when  rc.storname ='沈阳本部'and  zb.dbilldate >= to_char(sysdate - 4 ,'yyyy-mm-dd') then  db.noutsumnum else 0 end 沈阳调拨数量,
zb.dbilldate 单据日期,
zb.dauditdate 审核日期,
zb.taudittime ,
zb.user_name 制单人,
db.vcode 单号
,zb.fstatusflag 单据状态,
decode(zb.fstatusflag,5,'调拨中',7,'关闭',4,'审批完成',2,'审批中',1,'自由') 单据状态
 from nc5x.to_bill_b db
join nc5x.Bd_Stordoc rc
  on db.cinwhid= rc.pk_stordoc
join nc5x.Bd_Stordoc cc
  on db.coutwhid= cc.pk_stordoc
join nc5x.bd_invbasdoc ch
  on db.cinvbasid= ch.pk_invbasdoc
join ( select  zb.dplanenddate,zb.coperatorid,zb.cbillid,us.user_name,us.cuserid,zb.dbilldate,zb.dauditdate ,zb.fstatusflag,zb.taudittime 
       from nc5x.to_bill zb
       join nc5x.sm_user us
         on zb.coperatorid = us.cuserid and zb.dr = 0 ) zb
  on zb.cbillid = db.cbillid 
  and db.dr=0 
where 
zb.dbilldate >= '2024-06-01'
and cc.storname in ('北京仓')
and zb.fstatusflag in  (5,7)
and ch.width = '兼容'
-- and rc.storname  in  ('南京本部')


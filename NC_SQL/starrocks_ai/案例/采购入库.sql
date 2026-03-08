select  case when bd_billtype.billtypename like '采购' then '采购入库' 
else '调拨入库'end 入库方式,
          bd_stordoc.storname 入库仓库,
          ic_general_h.vbillcode 单据号,
         ic_general_h.dbilldate 入库时间,
         bd_invbasdoc.invpinpai 入库品牌,
          bd_invbasdoc.length 入库品类,
          cu.user_name 制单人,
          bd_invbasdoc.width 大类,
          bd_invbasdoc.invcode 存货编码,
          bd_invbasdoc.invname 存货名称,max(ic_general_h.dbilldate) 最后入库时间,
           sum(nvl(nc5x.ic_general_b.noutnum, 0)) + sum(nvl(nc5x.ic_general_b.ninnum, 0)) as 数量,
              count(nc5x.ic_general_h.dbilldate) as pl
              ,case when substr(ic_general_h.dbilldate,6,2)='01' then '1月'
 when substr(ic_general_h.dbilldate,6,2)='02' then '2月'
    when substr(ic_general_h.dbilldate,6,2)='03' then '3月'
       when substr(ic_general_h.dbilldate,6,2)='04' then '4月'  
          when substr(ic_general_h.dbilldate,6,2)='05' then '5月' 
           when substr(ic_general_h.dbilldate,6,2)='06' then '6月'
              when substr(ic_general_h.dbilldate,6,2)='07' then '7月'
                 when substr(ic_general_h.dbilldate,6,2)='08' then '8月'
                    when substr(ic_general_h.dbilldate,6,2)='09' then '9月'  
                       when substr(ic_general_h.dbilldate,6,2)='10' then '10月'
                          when substr(ic_general_h.dbilldate,6,2)='11' then '11月'
                             when substr(ic_general_h.dbilldate,6,2)='12' then '12月' end 月份
  from nc5x.ic_general_h
 inner join nc5x.ic_general_b
    on (nc5x.ic_general_h.cgeneralhid = nc5x.ic_general_b.cgeneralhid and
       nc5x.ic_general_b.dr = 0 and nc5x.ic_general_h.fbillflag >= 3) 
 inner join nc5x.bd_invbasdoc
    on (nc5x.ic_general_b.cinvbasid = nc5x.bd_invbasdoc.pk_invbasdoc)
 inner join nc5x.bd_billtype
    on (nc5x.ic_general_h.cbilltypecode = nc5x.bd_billtype.pk_billtypecode)
  left outer join nc5x.bd_stordoc       
    on (nc5x.ic_general_h.cwarehouseid = nc5x.bd_stordoc.pk_stordoc)
    left join  nc5x.sm_user cu on ic_general_h.coperatorid =cu.cuserid
where
  dbilldate between '2021-12-01' and '2021-12-31' and  (bd_billtype.billtypename like '%出库%') 
  and   bd_stordoc.storname in ('南京本部','西 安99库','重庆本部','成都本部','沈阳本部','哈尔滨本部','西安本部')
 group by bd_billtype.billtypename  , 
         bd_stordoc.storname  , 
          ic_general_h.dbilldate  , 
          bd_invbasdoc.invpinpai  , 
         bd_invbasdoc.length  , 
         cu.user_name  , 
         bd_invbasdoc.width  ,
          bd_invbasdoc.invcode , 
          bd_invbasdoc.invname ,
             ic_general_h.vbillcode
             
          

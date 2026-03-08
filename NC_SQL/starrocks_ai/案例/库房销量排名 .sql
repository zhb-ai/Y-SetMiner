select * from (
select d.分仓城市,d.存货编码,d.存货名称 ,dense_rank()OVER(PARTITION BY d.分仓城市
        ORDER BY  sum(d.数量) desc ) AS 排名,sum(d.数量) from (select cu.deptname as 市场部,
       cu.n_deptname as 部门, 
       cu.psnname as 业务员,
       cu.custname as 客户名称,
       ii.dbilldate as 日期,
       ii.vnote as 备注,
       ib.nnumber as 数量,
       ib.invcode as 存货编码,
       ib.invname as 存货名称,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌,
       ck.storname  仓库名称,case when ck.storname like '%1号库%'or ck.storname like '%科捷%'  then '北京'
     when ck.storname like '%成都%' then '成都'
       when ck.storname like '%哈尔滨%' then '哈尔滨'
         when ck.storname like '%南京%' then '南京'  
            when ck.storname like '%沈阳%' then '沈阳'
             when ck.storname like '%西安%' then '西安'
              when ck.storname like '%重庆%' then '重庆' end 分仓城市     
                              ,case when substr(ii.dbilldate,6,2)='01' then '1月'
 when substr(ii.dbilldate,6,2)='02' then '2月'
    when substr(ii.dbilldate,6,2)='03' then '3月'
       when substr(ii.dbilldate,6,2)='04' then '4月'  
          when substr(ii.dbilldate,6,2)='05' then '5月'
           when substr(ii.dbilldate,6,2)='06' then '6月'
              when substr(ii.dbilldate,6,2)='07' then '7月'
                 when substr(ii.dbilldate,6,2)='08' then '8月'
                    when substr(ii.dbilldate,6,2)='09' then '9月'  
                       when substr(ii.dbilldate,6,2)='10' then '10月'
                          when substr(ii.dbilldate,6,2)='11' then '11月'
                             when substr(ii.dbilldate,6,2)='12' then '12月' end 月份
  from nc5x.so_saleinvoice ii
  left join (select ib.csaleid,ib.nnumber,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode
          from nc5x.so_saleinvoice_b ib
          left join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
    on ib.csaleid = ii.csaleid
  join nc5x.v_zlw_cust cu
    on ii.creceiptcustomerid = cu.pk_cumandoc
  join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
 where  ii.dbilldate between '2020-03-01' and  '2020-05-31'and ib.width ='打印机' and   length(ib.invcode)=6  and ck.storname like '%南京%'--and  REGEXP_LIKE (ck.storname, '^(成都|哈尔滨|科捷仓|南京|沈阳|西安|重庆|1号库)')
 ) d  group by  d.存货编码,d.存货名称,d.分仓城市
)d -- where d.排名 <=30    






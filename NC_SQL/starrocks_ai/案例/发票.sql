--select ma.存货名称 ,sum(ma.数量) 销量,from (

select ii.csaleid ,
    ii.dbilldate as 日期,
    cu.deptname as 市场部,
    cu.n_deptname as 部门,
    cu.psnname as 业务员,
cu.pk_cumandoc 客户主键,
case when  yw.busicode = 's005' then '放货'else '销售'end 是否  放货 ,
       ii.vnote as 备注,
       ib.nnumber as 数量,
       ib.pk_invbasdoc 存货主键,
        ck.storname as 库房,
       ii.vreceiptcode 单据号,
        ii.dr
  from nc5x.so_saleinvoice ii
  join (select Ch.pk_invbasdoc,ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
    on ib.csaleid = ii.csaleid
  join nc5x.v_zlw_cust cu
  
    on ii.creceiptcustomerid = cu.pk_cumandoc
    LEFT join nc5x.bd_busitype yw
on ii.cbiztype = yw.pk_busitype
     left join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
 where ii.dbilldate >= '2020-01-01'
   and ii.dbilldate <= '2020-12-31'
   --and ii.dr=0
   
   --)ma
--and  ib.invname  like '%%'
 
 
--and   cu.n_deptname ='区域销售部'
--order by ii.dbilldate asc)ma
-- and sb.ts <=to_char(sysdate-1,'yyyy-MM-dd') || ' 00:00:00'    
--and yw.busicode <> 's005'







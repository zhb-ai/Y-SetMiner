
select    d.库房,d.存货编码,d.存货名称 ,d.日期,sum(d.数量) from (
select cu.deptname as 市场部,
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
 ck.storname  as 库房                
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
  
where  (ck.storname like '%科贸%'or ck.storname like '%盛购%' )and   ii.dbilldate between '2019-05-06'and '2019-05-31' and  ib.width ='原装'

) d  group by  d.存货编码,d.存货名称,d.库房,d.日期 








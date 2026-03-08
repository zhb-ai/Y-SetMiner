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
       ck.storname  仓库名称
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
 where  ii.dbilldate between '2020-06-01' and  '2020-06-31'


 --and   ib.invcode ='AE0025'
 --ii.dbilldate >= '2018-12-01'
   --and ii.dbilldate <= '2018-12-28'
   --and cu.deptname = '北京市场部'
--order by ii.dbilldate asc

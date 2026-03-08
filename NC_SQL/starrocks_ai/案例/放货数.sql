
/*放货销售*/
select cu.deptname as 市场部,
       cu.n_deptname as 部门,
       cu.psnname as 业务员,
       cu.custname as 客户名称,
       lx.businame as 业务类型,
       ii.dbilldate as 日期,
       ii.vnote as 备注，
       ib.nnumber as 数量,
       ib.nsummny as 价税合计,
       ib.invcode as 存货编码,
       ib.invname as 存货名称,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌
  from nc5x.so_saleinvoice ii
  join (select ib.csaleid,ib.nnumber,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.nsummny
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
    on ib.csaleid = ii.csaleid
  join nc5x.bd_busitype lx
    on ii.cbiztype = lx.pk_busitype
  join nc5x.v_zlw_cust cu
    on ii.creceiptcustomerid = cu.pk_cumandoc
 where ii.dbilldate between '2020-06-01'and  '2020-06-30'
   and lx.businame = '放货销售'and  cu.n_deptname ='区域销售部'
order by ii.dbilldate asc

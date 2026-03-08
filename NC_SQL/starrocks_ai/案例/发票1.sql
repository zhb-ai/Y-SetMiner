select cu.deptname as 市场部,
       cu.n_deptname as 部门,
       cu.psnname as 业务员,
       cu.custcode as 客户编码，
       cu.custname as 客户名称,
       ii.dbilldate as 日期,
       ii.vnote as 备注，
       ib.nnumber as 数量,
       ib.nsummny as 价税合计,
       ib.invcode as 存货编码,
       ib.invname as 存货名称,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌,
       ib.coriginalbillcode 
  from nc5x.so_saleinvoice ii
  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.coriginalbillcode
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
    on ib.csaleid = ii.csaleid
  join nc5x.v_zlw_cust cu
    on ii.creceiptcustomerid = cu.pk_cumandoc
 where ii.dbilldate >= '2020-08-01'
   and ii.dbilldate <= '2020-08-31'
 --and ib.invcode = 'DA0099'
order by ii.dbilldate asc

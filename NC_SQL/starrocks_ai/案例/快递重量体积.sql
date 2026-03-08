/*快递体积重量*/
select cu.deptname  as 市场部,
       cu.n_deptname  as 部门,
       cu.psnname  as 业务员,
       cu.custname  as 客户名称,
       ib.vreceiptcode  as 订单号,
       ib.CUPSOURCEBILLCODE as 出库单号 ,
       ib.PK_DEFDOC16 as 省份,
       ib.PK_DEFDOC20 as 市,
       ii.dbilldate  as 日期,
       ii.vdef9  as 运单号,
       ii.vdef7  as 货运公司,
       ib.vdef4  as 货运标记,
       ii.pk_defdoc6  as 件数运费,
       ck.storname  as 库房,
       ibb.invname  as 存货名称,
       ibb.nnumber  as 数量,
       ibb.width  as 大类,
       ib.vdef20 as 地址,
       ibb.nsummny,
       ibb.unitweight*ibb.nnumber as 重量,
       ibb.unitvolume*ibb.nnumber/1000000 as 体积
  from nc5x.so_saleinvoice ii
  join (select distinct ib.csaleid, s.vdef4 , s.vreceiptcode ,s.vnote,s.vdef20,PK_DEFDOC16,PK_DEFDOC20,ib.CUPSOURCEBILLCODE
          from nc5x.so_saleinvoice_b ib
          join nc5x.so_sale s
            on ib.coriginalbillcode = s.vreceiptcode and ib.dr = 0 ) ib
    on ib.csaleid = ii.csaleid
   and ii.dr = 0 
  left join nc5x.v_zlw_cust cu
    on ii.creceiptcorpid = cu.pk_cumandoc
  join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
  join (select ibb.csaleid,w.invname,w.width,ibb.nnumber,ibb.noriginalcurnetprice,w.unitvolume,w.unitweight ,ibb.nsummny
          from nc5x.so_saleinvoice_b ibb
          join nc5x.bd_invbasdoc w
            on ibb.cinvbasdocid = w.pk_invbasdoc)ibb
    on ibb.csaleid = ii.csaleid
 where ii.dbilldate >= '2022-05-01'
   and ii.dbilldate <= '2022-06-30'
  and ii.vdef7 like '%中通%'
   --and ii.vdef9 like 'JD%'
   --  and ib.vreceiptcode = 'SO2205050479'
   -- and  cu.deptname not in ('直营+微分销','大客户部','项目部')
order by ii.dbilldate asc , cu.custname asc,ii.vdef9 asc











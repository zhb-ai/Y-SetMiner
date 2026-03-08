/*快递体积重量*/
-- select 市场部,部门,业务员,客户名称,日期,sum(代垫运费)代垫运费,sum(兼容金额)兼容金额,sum(原装金额)原装金额 ,sum(重量) 重量,sum(体积)体积     from (
 select 市场部,部门,业务员,客户名称,日期,货运公司,运单号,订单号,库房,收货人,收货电话,地址,省,市,sum(代垫运费)代垫运费,sum(兼容金额)兼容金额,sum(原装金额)原装金额 ,sum(重量) 重量,sum(体积)体积     from (
select cu.deptname  as 市场部,
       cu.n_deptname  as 部门,
       cu.psnname  as 业务员,
       cu.custname  as 客户名称,
       ib.vreceiptcode  as 订单号,
m.PK_DEFDOC6 as 收货人,m.PK_DEFDOC17 收货电话,
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
       cu.sf 省,
       cu.cs 市,
       case when ibb.invname = '营销部代垫运费' then  ibb.nsummny else 0 end as 代垫运费,
       case when ibb.width = '兼容'and length(invcode)>4  then ibb.nsummny else 0 end as 兼容金额,
       case when ibb.width in('原装','打印机') and length(invcode)>4  then ibb.nsummny else 0 end as 原装金额,
       ibb.nsummny 总金额 ,
       ibb.unitweight*ibb.nnumber as 重量,
       ibb.unitvolume*ibb.nnumber as 体积
  from nc5x.so_saleinvoice ii
  join (select distinct ib.csaleid, s.vdef4 , s.vreceiptcode ,s.vnote,s.vdef20,coriginalbillcode
          from nc5x.so_saleinvoice_b ib
          join nc5x.so_sale s
            on ib.coriginalbillcode = s.vreceiptcode and ib.dr = 0) ib
    on ib.csaleid = ii.csaleid
   and ii.dr = 0 
  left join nc5x.v_zlw_cust cu
    on ii.creceiptcorpid = cu.pk_cumandoc
  join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
  join (select ibb.csaleid,w.invname,w.width,ibb.nnumber,ibb.noriginalcurnetprice,w.unitvolume,w.unitweight ,ibb.nsummny,w.invcode
          from nc5x.so_saleinvoice_b ibb
          join nc5x.bd_invbasdoc w
            on ibb.cinvbasdocid = w.pk_invbasdoc)ibb
    on ibb.csaleid = ii.csaleid
      left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
 where ii.dbilldate = to_char(sysdate-1,'yyyy-mm-dd')
  -- and cu.custname = '辽宁畅采商贸有限公司'
  --  and ii.vdef7 like  '%京东%'
   -- and ck.storname not in ('首创虚拟库')
    ) a  
 --group by 市场部,部门,业务员,客户名称,日期
  group by 市场部,部门,业务员,客户名称,日期,货运公司,运单号,订单号,库房,地址,省,市,收货人,收货电话

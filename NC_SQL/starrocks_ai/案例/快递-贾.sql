/*快递体积重量*/
-- select 市场部,部门,业务员,客户名称,日期,sum(代垫运费)代垫运费,sum(兼容金额)兼容金额,sum(原装金额)原装金额 ,sum(重量) 重量,sum(体积)体积     from (
select --运费结算方式,
市场部,部门,业务员,客户名称,日期,货运公司,运单号,订单号,库房,收货人,收货电话,省,市,存货编码,存货名称,
sum(代垫运费)代垫运费,sum(兼容金额)兼容金额,sum(原装金额)原装金额 ,sum(重量) 重量,sum(体积)体积 ,地址,sum(数量)   from (
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
m.VDEF4 as 运费结算方式,
ii.pk_defdoc6  as 件数运费,
ck.storname  as 库房,
ibb.invcode as 存货编码,
ibb.invname  as 存货名称,
ibb.nnumber  as 数量,
ibb.width  as 大类,
ib.vdef20 as 地址,
m.pk_defdoc16 省,
m.pk_defdoc20 市,
case when ibb.invname = '营销部代垫运费+保价费' then  ibb.nsummny else 0 end as 代垫运费,
case when ibb.width = '兼容'and length(invcode)>4  then ibb.nsummny else 0 end as 兼容金额,
case when ibb.width in('原装','打印机','电脑PC') and length(invcode)>4  then ibb.nsummny else 0 end as 原装金额,
ibb.nsummny 总金额 ,
ibb.unitweight*ibb.nnumber as 重量,
ibb.unitvolume*ibb.nnumber as 体积
  from nc5x.so_saleinvoice ii
  join (select distinct ib.csaleid, s.vdef4 , s.vreceiptcode ,s.vnote,s.vdef20,ib.coriginalbillcode
          from nc5x.so_saleinvoice_b ib
          join nc5x.so_sale s
            on ib.coriginalbillcode = s.vreceiptcode and ib.dr = 0 ) ib
    on ib.csaleid = ii.csaleid
   and ii.dr = 0 
  left join nc5x.v_zlw_cust cu
    on ii.creceiptcorpid = cu.pk_cumandoc
  join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
  left join (select ibb.csaleid,w.invname,w.width,ibb.nnumber,ibb.noriginalcurnetprice,w.unitvolume,w.unitweight ,ibb.nsummny,w.invcode
          from nc5x.so_saleinvoice_b ibb
          join nc5x.bd_invbasdoc w
            on ibb.cinvbasdocid = w.pk_invbasdoc)ibb
    on ibb.csaleid = ii.csaleid
  left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
where  ii.dr = 0 
-- and ibb.invname like '%上尊%'
and  ii.dbilldate between '2025-08-01'and '2025-08-31'
-- and ii.vdef9 = 'JDVA34948239018'
-- and ib.vreceiptcode = 'SO2211100010'
-- and ib.vreceiptcode in ('SO2302220561')
-- and ibb.invname = '营销部代垫运费'
-- and  ii.dbilldate >= '2025-0-01'
-- and  ck.storname in ('北京仓','南京仓','成都仓','重庆仓','西安仓','哈尔滨仓','沈阳仓')
and nvl(m.VDEF4,'包邮') <> '到付'
) a  group by   市场部,部门,业务员,客户名称,日期,货运公司,运单号,订单号,库房,省,市,收货人,收货电话,地址,存货编码,存货名称



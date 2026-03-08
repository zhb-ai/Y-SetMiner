-- Invoice offset details
-- Invoice offset details


select fstatus,customer_code,customer_name,order_date,NC订单号,订单号含退单原订单 ,sum(invoice_amount) NC金额 from (
select 
ii.fstatus,
bd.docname as distributor_company,
ii.vdef11 as business_attribute ,
ib.CORIGINALBILLCODE as NC订单号,
nvl(th.vsourcecode,ib.CORIGINALBILLCODE ) as 订单号含退单原订单,
ii.VRECEIPTCODE as invoice_no,
cu.pk_cubasdoc as customer_primary_key,
cu.custcode as customer_code,
cu.custname as customer_name ,
ii.dbilldate as order_date,
ib.nsummny as invoice_amount, 
ii.ntotalsummny as invoice_amount_sum,
ib.width as big_class,
ib.invcode as invcode ,
ib.invname as invname,
ib.def19 as tax_receipt_module,
dd.storname as warehouse,
cu.n_deptname as department,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as sales_man,
fb.ddh as hx_order_no,
fb.verifyfinisheddate as write_off_date,
yw.busicode 
from nc5x.so_saleinvoice ii left  join (
select ib.csaleid,ib.nnumber,ib.nsummny,
ch.invpinpai,ch.height,ch.width,ch.length,
ch.invname,ch.invcode,ib.blargessflag ,
ch.pk_invbasdoc,ib.coriginalbillcode, 
ib.noriginalcurmny,ch.def2 ,ch.def19,
ch.unitvolume ,ch.unitweight 
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu 
on ii.creceiptcorpid  = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_psndoc  us
on us.pk_psndoc= ii.cemployeeid
left join nc5x.bd_stordoc dd
on ii.cwarehouseid = dd.pk_stordoc
left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
left join (
select distinct bj.ddh,verifyfinisheddate,isverifyfinished  from nc5x.arap_djfb  bj
left join (select distinct ddh from nc5x.arap_djfb where isverifyfinished = 'N' AND DR= 0) kj
on bj.ddh = kj.ddh
where  DR= 0 and isverifyfinished = 'Y'and kj.ddh is null 
 )  fb 
on fb.ddh=m.vreceiptcode
left join nc5x.bd_defdoc bd 
on ii.PK_DEFDOC5 = bd.PK_DEFDOC  
left join nc5x.so_apply th 
on ib.CORIGINALBILLCODE = th.vreceiptcode 
where ii.dr = 0 
and ii.dbilldate >= '2024-01-01'
and ii.fstatus = '1'
and cu.custcode in ('1101b188','13001227192','1101b191','13041282466')
--- and cu.custcode in ('1101b188')
-- and nvl(th.vsourcecode,ib.CORIGINALBILLCODE ) = '293428633654'
) a 
group by fstatus,customer_code,customer_name,order_date,NC订单号,订单号含退单原订单

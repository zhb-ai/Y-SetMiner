--采购在途
select
bb.invcode   存货编码,
bb.invname   存货名称,
bb.width   大类,
bb.invpinpai   品牌,
bb.length   品类,
bb.height   小类,
case when gg.nabprice is NUll then (case when gg.noutnum = 0 then 0 else round(gg.noutmny/gg.noutnum,2)end) else gg.nabprice  end 结存单价,
gg.cinventoryid  主键
from nc5x.bd_invbasdoc bb
join (select ee.pk_invmandoc , ff.cinventoryid ,ee.pk_invbasdoc,ff.nabprice,ff.caccountmonth,ff.noutmny,ff.noutnum
      from nc5x.bd_invmandoc ee
      join nc5x.ia_generalledger ff
      on ee.pk_invmandoc=ff.cinventoryid ) gg
on gg.pk_invbasdoc=bb.pk_invbasdoc
where bb.width in ('兼容','原装','打印机')
-- where bb.width in ('兼容')
and gg.caccountmonth<> '00'



select 
distinct
p.vordercode as 单据号,
case when rc.storcode in ('084','086','001') then '北京' when rc.storcode in ('087','092','022') then '南京' else '其他' end 城市,
rc.storname 入仓仓库,
p.dauditdate 审批日期,
p.dorderdate 单据日期,
case when p.dauditdate >= to_char(sysdate-15,'yyyy-mm-dd')then  '否' else '是' end 订单时间是否大于半月,
decode(p.forderstatus,3,'审核') as 订单状态,
ch.invcode 存货编码,
ch.invname 存货名称,
ch.width 大类,
xx.custname 供应商名称,
pb.nordernum  数量,
pb.ntaxpricemny 含税金额,
p.vmemo as 备注
from nc5x.po_order p 
left join nc5x.po_order_b pb
on  p.corderid =pb.corderid 
join nc5x.bd_invbasdoc ch
on pb.cbaseid = ch.pk_invbasdoc                                                                                                                                                                                                 
left join nc5x.po_invoice_b bb
on pb.corderid = bb.corderid
left join nc5x.Bd_Stordoc rc
on pb.cwarehouseid= rc.pk_stordoc
join nc5x.bd_cubasdoc xx
on p.cvendorbaseid =xx.pk_cubasdoc
where 
bb.ninvoicenum is  null
and p.dauditdate >= to_char(sysdate-15,'yyyy-mm-dd')   
and  p.forderstatus = 3 
and  ch.width in ('原装','打印机') 
and p.dr = 0
and pb.dclosedate is null 
and pb.naccumstorenum is null 
and rc.storcode in ('084','086','087','092','001','022')
-- and vordercode in ('CD2212160072')



--select pb.*  from nc5x.po_order p 
--left join nc5x.po_order_b pb
 --on  p.corderid =pb.corderid  where vordercode in ('CD2212160072','CD2212210081') 

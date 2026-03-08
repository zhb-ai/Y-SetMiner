--采购在途
select 
distinct
p.dauditdate 审批日期,
p.dorderdate 单据日期,
p.dr,
 bb.ninvoicenum,
decode(p.forderstatus,3,'审核') as 订单状态,
ch.invcode 存货编码,
ch.invname 存货名称,
ch.width 大类,
pb.nordernum  数量,
pb.ntaxpricemny 含税金额,
p.vordercode as 单据号,
p.vmemo as 备注,
rc.storname 入仓仓库
 from nc5x.po_order p 
left join nc5x.po_order_b pb
 on  p.corderid =pb.corderid 
 join nc5x.bd_invbasdoc ch
  on pb.cbaseid = ch.pk_invbasdoc                                                                                                                                                                                                 
    left join nc5x.po_invoice_b bb
   on pb.corderid = bb.corderid
   left join nc5x.Bd_Stordoc rc
  on pb.cwarehouseid= rc.pk_stordoc
where 
 bb.ninvoicenum is  null
and p.dauditdate >= to_char(sysdate-16,'yyyy-mm-dd')   
and  p.forderstatus = 3 
-- and  ch.width in ('原装','打印机') 
and  ch.width in ('兼容','原装','打印机') 
and p.dr = 0
-- and rc.storname like  '%南京%'

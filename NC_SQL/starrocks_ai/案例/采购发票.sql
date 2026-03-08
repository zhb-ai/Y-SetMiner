
select m.供应商名称,存货编码,存货名称,月份,单价, sum(价税合计) 价税合计 , sum(数量) 数量 from (
select/*采购发票金额*/
aa.dinvoicedate as 日期,
-- row_number() over(order by cc.invcode,aa.dinvoicedate desc ) ,
substr(aa.dinvoicedate,1,7) as 月份,
yy.custname as 供应商名称,
cc.invcode as 存货编码,
cc.invname as 存货名称,
bb.ninvoicenum as 数量,
bb.nsummny as 价税合计,
bb.nsummny/bb.ninvoicenum as 单价,
cc.length as 品类,
cc.invpinpai as 品牌,
cc.width as 大类,
p.vordercode 单号  ,
p.dr ,
ck.storname,
su1.user_name as 制单人,
p.forderstatus ,          
bb.cwarehouseid
from nc5x.po_invoice_b bb
join nc5x.po_invoice aa
on bb.cinvoiceid = aa.cinvoiceid
join nc5x.bd_invbasdoc cc
on bb.cbaseid = cc.pk_invbasdoc
join (select xx.custname,aa.cvendorbaseid,aa.cinvoiceid
  from nc5x.po_invoice aa
  join nc5x.bd_cubasdoc xx
    on aa.cvendorbaseid =xx.pk_cubasdoc )yy
on yy.cinvoiceid = aa.cinvoiceid and aa.dr = 0
left join nc5x.bd_stordoc ck
on bb.cwarehouseid = ck.pk_stordoc
left join nc5x.po_order p
on p.corderid = bb.corderid
left join nc5x.sm_user  su1 
on p.coperator = su1.cuserid
where (1=1)
and cc.invpinpai = '华为'
and ck.storname = '工厂直发库'
-- and cc.length = '笔记本'
---and su1.user_name = '石鑫鑫'
-- and cc.width = '电脑PC'

-- and p.vordercode = 'CD2401020034'
-- and cc.invcode = 'CE0338'
-- and cc.width='兼容'
-- and cc.invpinpai in ('华为','奔图','惠普')
-- and bb.ninvoicenum > 0

-- and yy.custname in ('联强国际贸易(中国)有限公司','上海神州数码有限公司','伟仕佳杰（重庆）科技有限公司','英迈电子商贸（上海）有限公司','紫光数码（苏州）集团有限公司')

-- and (yy.custname  like '%联强%' or yy.custname in ('联强国际贸易(中国)有限公司','上海神州数码有限公司','伟仕佳杰（重庆）科技有限公司','英迈电子商贸（上海）有限公司','紫光数码（苏州）集团有限公司'))
-- and cc.invpinpai like '%惠普%'
and aa.dinvoicedate between  '2023-12-19' and '2024-03-19'
and yy.custname = '华为终端有限公司'

order by  aa.dinvoicedate desc 
-- and yy.custname = '北京鑫博网电子商务有限公司'
--and  yy.custname like '%中山澳兴发%'
--and regexp_like(cc.invname ,'(388|278|912|925|337|328|2612|303|FX-9|7516|912|925|214|7570)')
) m  group by  m.供应商名称,存货编码,存货名称 ,月份,单价

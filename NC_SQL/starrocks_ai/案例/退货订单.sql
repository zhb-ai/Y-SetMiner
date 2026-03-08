-- 退货订单
select 
aa.vreceiptcode thorder_no,
aa.dmakedate as thorder_date,
aa.vsourcecode  order_no,
hl.dapprovedate  order_date,

cu.pk_cubasdoc customer_primary_key,
cu.custname,
cu.psnname,
ch.invcode as invcode,
ch.invname as invname,
bb.nnumber as return_num,
ch.width as maincategorie,
ch.invpinpai as brand,
ch.length as category,
ch.height as subclass,
th.vreasonname as return_reason,
aa.vnote as vnote,
dd.storname as storname
from nc5x.so_apply aa
join nc5x.so_apply_b bb
on aa.pk_apply = bb.pk_apply
join nc5x.bd_stordoc dd
on bb.cbodywarehouseid = dd.pk_stordoc
join nc5x.so_returnreason th
on bb.pk_returnreason = th.pk_returnreason
LEFT join nc5x.v_zlw_cust  cu
on aa.ccustomerid = cu.pk_cumandoc
join nc5x.bd_invbasdoc ch
on bb.cinvbasdocid = ch.pk_invbasdoc
left join nc5x.so_sale hl
on aa.vsourcecode = hl.vreceiptcode
where 
aa.dmakedate >= to_char(sysdate - 181,'yyyy--mm-dd')
and ch.width in ('兼容','原装','打印机','电脑PC')
-- and  hl.dapprovedate <>  hl.dmakedate
and cu.deptname <> '直营+微分销'






-- 退货订单
select 
aa.vreceiptcode thorder_no,
aa.dmakedate as thorder_date,
aa.vsourcecode  order_no,
hl.dapprovedate  order_date,

cu.pk_cubasdoc customer_primary_key,
ch.invcode as invcode,
ch.invname as invname,
bb.nnumber as return_num,
ch.width as maincategorie,
ch.invpinpai as brand,
ch.length as category,
ch.height as subclass,
th.vreasonname as return_reason,
aa.vnote as vnote,
dd.storname as storname
from nc5x.so_apply aa
join nc5x.so_apply_b bb
on aa.pk_apply = bb.pk_apply
join nc5x.bd_stordoc dd
on bb.cbodywarehouseid = dd.pk_stordoc
join nc5x.so_returnreason th
on bb.pk_returnreason = th.pk_returnreason
LEFT join nc5x.v_zlw_cust  cu
on aa.ccustomerid = cu.pk_cumandoc
join nc5x.bd_invbasdoc ch
on bb.cinvbasdocid = ch.pk_invbasdoc
left join nc5x.so_sale hl
on aa.vsourcecode = hl.vreceiptcode
where 
aa.dmakedate >= to_char(sysdate - 181,'yyyy--mm-dd')
and ch.width in ('兼容','原装','打印机','电脑PC')
and  hl.dapprovedate <>  aa.dmakedate
and dd.storcode in ('001',
'013',
'005',
'043',
'051',
'022',
'056',
'017',
'058',
'052',
'020',
'02202',
'01703',
'07603',
'099')
and cu.deptname <> '直营+微分销'


-- and dd.storname in ('北京仓',
--'科贸3A003','科贸3H006','盛购2-650','成都仓',
--'南京仓','西安仓','沈阳仓',
--'重庆仓','成 都门市','哈尔滨仓','南 京99库','沈 阳兼容99库','中山慧采仓','北 京99库')









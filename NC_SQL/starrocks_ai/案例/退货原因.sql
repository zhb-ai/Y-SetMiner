
/*加退后原因*/
select distinct
VRECEIPTCODE,
VFIRSTCODE,
aa.dmakedate as 日期,
yy.custname as 客商名称,
zz.invcode as 存货编码,
zz.invname as 存货名称,
zz.nnumber as 退货数量,
zz.width as 大类,
zz.invpinpai as 品牌,
zz.length as 品类,
zz.height as 小类,
xx.vreasonname as 退货原因,
aa.vnote as 备注,
dd.storname as 仓库,
noriginalcursummny
from nc5x.so_apply aa
join nc5x.so_apply_b bb
  on aa.pk_apply = bb.pk_apply
join nc5x.bd_stordoc dd
  on bb.cbodywarehouseid = dd.pk_stordoc
join (select th.vreasonname,th.pk_returnreason,bb.pk_apply
        from nc5x.so_apply_b bb
        join nc5x.so_returnreason th
          on bb.pk_returnreason = th.pk_returnreason)xx
  on xx.pk_apply=aa.pk_apply
join (select ks.custname,ks.pk_cubasdoc，kg.pk_cumandoc
        from nc5x.bd_cumandoc kg
        join nc5x.bd_cubasdoc ks
          on kg.pk_cubasdoc = ks.pk_cubasdoc) yy
  on yy.pk_cumandoc=aa.ccustomerid
join (select bb.cinvbasdocid,bb.pk_apply,ch.pk_invbasdoc,ch.invname,ch.width,ch.invpinpai,ch.length,ch.height,bb.nnumber,ch.invcode
        from nc5x.so_apply_b bb
        join nc5x.bd_invbasdoc ch
          on bb.cinvbasdocid = ch.pk_invbasdoc) zz
  on zz.pk_apply = aa.pk_apply
where --  aa.dmakedate >='2023-02-01'
 dd.storname like '%虚拟%'
-- and aa.dmakedate <='2022-09-07'
---and zz.width ='兼容' 
and VRECEIPTCODE  ='3U2208220034'
and VFIRSTCODE = 'SO2302131409'



select distinct VRECEIPTCODE 退货单号,xx.vreasonname 退货原因  from nc5x.so_apply aa
join nc5x.so_apply_b bb
on aa.pk_apply = bb.pk_apply
join (select th.vreasonname,th.pk_returnreason,bb.pk_apply
from nc5x.so_apply_b bb
join nc5x.so_returnreason th
on bb.pk_returnreason = th.pk_returnreason where th.dr = 0
 )xx
on xx.pk_apply=aa.pk_apply
left join nc5x.sm_user w
on aa.CAPPROVEID =w.cuserid
where aa.dmakedate >='2022-09-13'
and aa.dmakedate <='2022-09-21' 
and VFIRSTCODE = 'SO2302131409'
-- and aa.dr = 0 and VRECEIPTCODE not in ('3U2203210109','3U2203170084','3U2203040019')
and bb.dr = 0 
AND VRECEIPTCODE like '%3U%'
-- and VRECEIPTCODE = '3U2209190159' 




select DISTINCT VRECEIPTCODE as return_order,VFIRSTCODE as original_order_no
 from nc5x.so_apply aa
join nc5x.so_apply_b bb
on aa.pk_apply = bb.pk_apply 
and aa.dr = 0 and bb.dr = 0  
where aa.dmakedate >= '2022-05-01'  
AND VRECEIPTCODE like '%3U%'


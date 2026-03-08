select
distinct 
s.vreceiptcode || '|'|| a.pk_cubasdoc  as RK ,
s.vreceiptcode as order_no ,
a.pk_cubasdoc as customer_key ,
a.custname as customer_name,
a.deptname as marketing_department,
a.n_deptname as department,
a.psnname as salesman,
yw.businame as payment_type,
s.dbilldate as order_time,
s.nheadsummny as total,
s.fstatus,
ii.vdef11,
case when a.custcode in ('FP15541168801','13700184649','13504985396','13644280966','18604035135','13500765446',
'13342170902','13841526427','13478447676','13354062444','13387878292','13941565557','13942849827','13942054656',
'13674116028','13842811263','13941175917','18698641718','18643983773','0411-87633553','13904482600','018645641925')
then '疑似外贸' else '代发'end  cum_lab
from nc5x.so_sale s
join nc5x.v_zlw_cust a
  on s.ccustomerid = a.PK_CUMANDOC
join nc5x.bd_busitype yw
on s.cbiztype = yw.pk_busitype
left  join  nc5x.so_saleinvoice_b ib 
on ib.coriginalbillcode =s.vreceiptcode
left join nc5x.so_saleinvoice ii
on ib.csaleid = ii.csaleid
left join (select distinct aa.VSOURCECODE as vreceiptcode 
 from nc5x.so_apply aa
join nc5x.so_apply_b bb
on aa.pk_apply = bb.pk_apply where aa.dmakedate >= '2022-11-01' and aa.dr = 0 and bb.dr = 0  AND VRECEIPTCODE like '%3U%' ) th
on s.vreceiptcode = th.vreceiptcode
where 
s.dr = 0
and s.fstatus in (2,6)
and ((
s.dbilldate >= '2022-11-01' 
and s.vdef17 = 'Y'
and s.nheadsummny >= 30000
and a.deptname not in ('直营+微分销')
and yw.businame <> '渠道现结' 
and th.vreceiptcode is null 
and a.custname not like '%齐心%') or 
(a.custcode in ('FP15541168801',
'13700184649',
'13504985396',
'13644280966',
'18604035135',
'13500765446',
'13342170902',
'13841526427',
'13478447676',
'13354062444',
'13387878292',
'13941565557',
'13942849827',
'13942054656',
'13674116028',
'13842811263',
'13941175917',
'18698641718',
'18643983773',
'0411-87633553',
'13904482600',
'018645641925') and s.dbilldate >= '2023-03-01'))



-- and s.vreceiptcode = '13349570009'










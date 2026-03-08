select 
nvl(cu.pk_cubasdoc,'yangfannali')||vreceiptcode||ch.invcode  main_key,
nvl(cu.deptname,'大客户部') as marketing_department,
nvl(cu.n_deptname,'大客户部') as department,
nvl(cu.psnname,us.psnname)  as sales_man,
nvl(cu.pk_cubasdoc,'yangfannali') as customer_primary_key,
nvl(cu.custcode,'yangfannali') as customer_code,
nvl(cu.custname,'北京扬帆耐力贸易有限公司') as customer_name , 
vreceiptcode as order_num ,
yd.vdef5 as distributor_company,
decode(fstatus,1,'自由',2,'审核',4,'关闭') as audit_status,
dbilldate as order_date,
ch.invcode as product_code,
ch.invname as product_name,
ch.width as big_class,
ch.invpinpai as brand,
ch.length as category,
ch.height as sub_class,
invbarcode as bar_code,
nnumber as out_num ,
vnote remark ,
yd.pk_defdoc6 as consignee,
yd.pk_defdoc17 as phone,
yd.pk_defdoc16 as province,
yd.pk_defdoc20 as city,
yd.vdef20 as shipping_address
from nc5x.so_preorder yd 
left join nc5x.so_preorder_b ydd
on yd.pk_preorder = ydd.pk_preorder
join nc5x.bd_invbasdoc ch
on ydd.cinvbasdocid = ch.pk_invbasdoc
left join nc5x.v_zlw_cust cu 
on yd.creceiptcorpid  = cu.pk_cumandoc
left join nc5x.bd_psndoc  us
on us.pk_psndoc= yd.cemployeeid
where yd.dr = 0 and dbilldate >='2023-01-01'

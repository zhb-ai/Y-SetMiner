select 
distinct 
hl.vreceiptcode 单据号,
cu.custcode as 客户编码,
nvl(cu.custname,'北京扬帆耐力有限公司') as 客户名称,
cu.deptname as 市场部,
cu.n_deptname as 部门, 
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
us.psnname as 订单业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) as 结算日期,
hl.dapprovedate  审批日期,
hl.dbilldate 单据日期,
nheadsummny 金额 
 from nc5x.so_sale hl 
left join  nc5x.so_squaredetail js
on js.csourcebillid = hl.csaleid
LEFT join nc5x.bd_busitype  yw
on hl.cbiztype = yw.pk_busitype
LEFT join nc5x.v_zlw_cust  cu
on hl.ccustomerid = cu.pk_cumandoc
left join nc5x.bd_psndoc  us
on us.pk_psndoc= hl.cemployeeid
where hl.dapprovedate >= '2024-01-01' 
and yw.businame = '放货销售' 
and hl.dr = 0 



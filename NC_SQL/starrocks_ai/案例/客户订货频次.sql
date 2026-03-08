
/*客户订货频率*/
select 
aa.pk_cubasdoc 客户主键,
aa.custcode as 客户编码,
aa.custname as 客户名称,
aa.deptname as 市场部,
aa.n_deptname as 部门,
aa.psnname as 业务员,
count (aa.dbilldate) as 九十天次数,
count(case when aa.dbilldate >= to_char(sysdate-30,'yyyy-mm-dd') then aa.dbilldate else null end ) as   三十天次数
from (select distinct
a.pk_cubasdoc,
a.custcode,
a.custname,
a.deptname,
a.n_deptname,
a.psnname,
s.dbilldate
from nc5x.so_saleinvoice s
join nc5x.v_zlw_cust a
  on s.creceiptcustomerid = a.pk_cumandoc
join nc5x.bd_busitype yw
on s.cbiztype = yw.pk_busitype
where s.dbilldate >= to_char(sysdate-90,'yyyy-mm-dd')
--and yw.busicode <> 's005'
)aa
group by aa.pk_cubasdoc,aa.custcode,aa.custname,aa.deptname,aa.n_deptname,aa.psnname order by aa.pk_cubasdoc 

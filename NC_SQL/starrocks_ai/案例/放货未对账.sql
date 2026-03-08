--***放货未结算***--- 

 SELECT  yw.busicode 业务类型,c.cbiztype ,cinvbasdocid 存货主键,a.csaleid ,a.ccustomerid ,cu.custname 客户名称 ,a.coriginalbillcode 单据号  ,decode( c.fstatus,1,'审核',2,'结束' ) 状态,a.nnumber 数量, a.noriginalcursummny   价税合计,a.noriginalcurtaxprice  单价   FROM  NC5X.so_saleinvoice_b a  join  NC5X.so_saleinvoice c  on a.csaleid=c.csaleid 
  left join nc5x.so_squaredetail b  on b.vreceiptcode  = a.csourcebillbodyid
  LEFT join nc5x.bd_busitype yw
on c.cbiztype = yw.pk_busitype
  LEFT join nc5x.v_zlw_cust cu
on a.ccustomerid = cu.pk_cumandoc
    where a.coriginalbillcode in ('POSNO200430000967','SO2005060691')
 -- where c.fstatus   in ('1','2')

/*加退后原因*/
--近一季度
select distinct
us.user_name,
aa.dr,
aa.vreceiptcode  退货单号,
aa.vsourcecode  外部单号,
aa.dmakedate as 日期,
aa.ccustomerid as 客户主键,
yy.custcode as 客户编码_,
yy.custname as 客商名称_,
zz.invcode as 存货编码,
zz.invname as 存货名称,
zz.nnumber as 退货数量,
zz.width as 大类,
zz.invpinpai as 品牌,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.psnname as 业务员,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
zz.length as 品类,
zz.height as 小类,
xx.vreasonname as 退货原因,
aa.vnote as 备注,
aa.vdef8 服务商,
dd.storname as 仓库
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
join ( select ks.custcode, ks.custname,ks.pk_cubasdoc,kg.pk_cumandoc
        from nc5x.bd_cumandoc kg
        join nc5x.bd_cubasdoc ks
          on kg.pk_cubasdoc = ks.pk_cubasdoc ) yy
  on yy.pk_cumandoc=aa.ccustomerid
join (select bb.cinvbasdocid,bb.pk_apply,ch.pk_invbasdoc,ch.invname,ch.width,ch.invpinpai,ch.length,ch.height,bb.nnumber,ch.invcode
        from nc5x.so_apply_b bb
        join nc5x.bd_invbasdoc ch
          on bb.cinvbasdocid = ch.pk_invbasdoc) zz
            on zz.pk_apply = aa.pk_apply
left join nc5x.v_zlw_cust cu 
on aa.ccustomerid = cu.pk_cumandoc 
left join nc5x.sm_user us
on aa.coperatorid = us.cuserid         
where aa.dmakedate >=  '2021-06-01'
and cu.deptname  <>  '直营+微分销' and cu.n_deptname like '%南京%'
and aa.dr =0 
-- and aa.vdef8 is not null 
order by aa.dmakedate asc 




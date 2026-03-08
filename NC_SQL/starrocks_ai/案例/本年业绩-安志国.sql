SELECT cub.pk_cubasdoc as 客户主键,cub.custname as 客户名称,cum.deptname as 市场部,cum.n_deptname as 部门,cum.psnname as 业务员,yj.*

FROM nc5x.bd_cubasdoc cub
join  (
select substr(deptcode,1,4) deptcode,
(case
when substr(dept.deptcode, 1, 6) in ( '030400','030441')  then
'区域销售部'
when substr(dept.deptcode, 1, 4) = '0303' then
'北京市场部'
when substr(dept.deptcode, 1, 4) = '0304' then
'外阜市场部'
when substr(dept.deptcode, 1, 4) = '1005' then
'B2B业务部'
when substr(dept.deptcode, 1, 2) = '10' then
'直营+微分销'
else dept.deptname end) deptname,
dept.deptname n_deptname,
psn.psnname psnname,
pay.termname,
pay.termid,
cum.*
from nc5x.bd_cumandoc cum
join nc5x.bd_deptdoc dept
on cum.pk_respdept1 = dept.pk_deptdoc
join nc5x.bd_psndoc psn
on cum.pk_resppsn1 = psn.pk_psndoc
left join nc5x.bd_payterm pay
on cum.pk_payterm = pay.pk_payterm
and cum.dr = 0
where cum.custflag in ('0', '2')
and cum.pk_corp = '1006'
and cum.dr = 0) cum
on cub.pk_cubasdoc = cum.pk_cubasdoc and cub.dr = 0

left join( select cl.pk_areacl,c.areaclname sf,cl.areaclname cs 
from nc5x.bd_areacl c 
left join nc5x.bd_areacl cl 
on c.pk_areacl = cl.pk_fatherarea )dq 
on cub.pk_areacl = dq.pk_areacl
left join nc5x.so_cucredit redit
on cub.pk_cubasdoc = redit.pk_cubasdoc
and redit.climittypeid = '0001A110000000002EXU'
and redit.vcredittypename = '2'
and redit.dr =0
left join nc5x.so_cucredit redits
on cub.pk_cubasdoc = redits.pk_cubasdoc
and redits.climittypeid = '0001A110000000002EXV'
and redits.vcredittypename = '2'
and redits.dr =0
left join (
select 客户主键,sum(兼容流水) 兼容流水 ,sum(原装流水) 原装流水,sum(打印机流水) 打印机流水,sum(电脑PC流水) 电脑PC流水 ,sum(流水) 总流水 from  (
select
cu.pk_cubasdoc 客户主键,
case when cg.width = '兼容' then
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end 
else 0 end   AS 兼容流水,
case when cg.width = '原装' then
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end 
else 0 end   AS 原装流水,
case when cg.width = '打印机' then
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end 
else 0 end   AS 打印机流水,
case when cg.width = '电脑PC' then
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end 
else 0 end   AS 电脑PC流水,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end  AS 流水,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期
from nc5x.so_squaredetail js
left join  nc5x.so_square zjs on js.csaleid = zjs.csaleid 
LEFT join (
select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,ch.unitweight,ch.unitvolume,
cg.refsaleprice as 批发售价
,cg.def5 as 代理价 
,cg.lowestprice   as 最低限价
from nc5x.bd_invmandoc cg
join nc5x.bd_invbasdoc ch
on cg.pk_invbasdoc = ch.pk_invbasdoc )cg
on js.cinventoryid = cg.pk_invmandoc
LEFT join nc5x.bd_busitype  yw
on js.cbiztype = yw.pk_busitype
LEFT join nc5x.v_zlw_cust  cu
on js.ccustomerid = cu.pk_cumandoc
left join nc5x.bd_psndoc  us
on us.pk_psndoc= js.cemployeeid
left join nc5x.so_sale hl
on js.csourcebillid = hl.csaleid
left join nc5x.sm_user  su1 
on hl.coperatorid = su1.cuserid
left join nc5x.bd_stordoc dd
on js.cwarehouseid = dd.pk_stordoc
where 
length(cg.invcode) >= 5
and js.dr=0
and (js.dapprovedate between '2023-01-01' and '2023-12-28' or js.dmakedate  between '2023-01-01' and '2023-12-28' )) group by 客户主键
) yj 
on cub.pk_cubasdoc = yj.客户主键

where (1=1) 
and  cum.deptname  <> '直营+微分销'
-- and dcu.addrname  like '%北京市%海淀区%连桥%'
-- and  cum.pk_cumandoc in ('1006A1100000000RI26L')
 and (case when (cum.sealflag is not null or length(ltrim(rtrim(cum.sealflag))) > 0 ) then 'Y' ELSE 'N' END )  ='N'
--  and cum.psnname  = '沙增硕'


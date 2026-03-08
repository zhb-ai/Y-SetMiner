select 
ma.财务小时,
ma.财务时间,
ma.财务日期
,ma.单据号
,ma.大类 
,ma.业务员
,ma.部门
,ma.部门分类
,ma.客户主键
,sum(ma.流水)流水
,sum(ma.成本) 成本
,sum(ma.毛利) 毛利  
from (
select 
js.ccustomerid 客户主键,
js.vreceiptcode 单据号,
substr(js.ts,1,10)财务日期,
substr(js.ts,1,19) 财务时间,
substr(js.ts,12,2) 财务小时,
cg.width as 大类,
nvl(m.nabprice, round(m.noutmny/m.noutnum,2)) as  结存单价 ,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
case  when nvl(m.nabprice, round(m.noutmny/m.noutnum,2)) is null then case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2))end  else nvl(m.nabprice, round(m.noutmny/m.noutnum,2))*js.nnewbalancenum  end   AS 成本,
case when  nvl(m.nabprice, round(m.noutmny/m.noutnum,2)) is null then 0 else (case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end ) end - nvl(m.nabprice, round(m.noutmny/m.noutnum,2))*js.nnewbalancenum  as 毛利,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期,
case when cu.deptname ='直营+微分销' and cu.psnname  in ('孙希宝','刘鱼浩','郑洁','张学兵') then '慧采-产品'
when cu.deptname <> '直营+微分销' then '渠道-产品'
else '线上-产品'   end 部门分类
from nc5x.so_squaredetail js
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
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
left join 
nc5x.ia_generalledger  m on m.cinventoryid = cg.pk_invmandoc
where 
length(cg.invcode) <> 4
and js.dr=0
and  m.caccountmonth<> '00' and m.noutnum <> 0 and m.dr = 0 
and cg.width in ('原装','兼容','打印机','电脑PC','智能家居')
-- and cu.deptname is not null  
-- and cu.custcode not in ('1101b191','13041282466')
and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) =  to_char(sysdate,'yyyy-mm-dd')
   )ma group by  ma.财务小时,ma.财务日期,ma.财务时间,ma.单据号,ma.大类 ,ma.业务员,ma.部门,ma.部门分类 ,ma.客户主键

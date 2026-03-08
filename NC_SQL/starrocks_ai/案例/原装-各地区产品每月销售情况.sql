select 月份,大类,存货名称,品牌,品类,小类,省,sum(流水)流水,sum(毛利) 毛利,sum(数量) 数量 from 
( select
case when cu.deptname ='直营+微分销' and (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) in ('孙希宝','张学兵','刘鱼浩') then '电商业务' 
when cu.deptname ='直营+微分销'   and (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end)  ='崔小帅' then '线上业务'
when cu.deptname ='直营+微分销'  then '线上业务'
when cu.deptname = 'SI业务部' then 'SI业务部' 
when cu.deptname = '大客户部'or cu.n_deptname is null  then '客户业务'
when cu.deptname = '平台业务部' then '平台业务'
when cu.deptname not in ('渠道部','外阜市场部','北京市场部','区域销售部') then '其他'
when cu.n_deptname like '%南京%' then '南京分公司'
when cu.n_deptname like '%西安%' then '西安分公司'
when cu.n_deptname like '%沈阳%' then '沈阳分公司'
when cu.n_deptname like '%哈尔滨%' then '哈尔滨分公司'
when cu.n_deptname like '%成都%' then '成都分公司'
when cu.n_deptname like '%重庆%' then '重庆分公司'
else cu.deptname  end 市场部分配 ,
hl.vreceiptcode  as 单据号 ,
zjs.vreceiptcode , 
js.vdef8 ,
js.vreceiptcode ,
js.cbodywarehouseid ,
js.ccustomerid 主键,
cu.pk_cubasdoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
js.nnewbalancenum as 数量,
js.blargessflag as 是否赠品,
cg.批发售价,
cg.代理价,
cg.最低限价,
nvl(cg.代理价,cg.批发售价) 批发价,
yw.businame as 业务类型,
js.vdef11 as 业务属性,
case when js.blargessflag = 'Y' then 0 else js.nsummny end  as 本币价税合计 ,
js.nnewbalancenum*js.vbodydef5 as 批发价税合计,
(CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END) AS 价税合计,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end-js.ncostmny AS 毛利,
(case  nvl2( TRIM(REGEXP_replace(js.VBODYDEF8,'[0-9|+|-|.]','')),0,1)  when 1 then to_number(js.VBODYDEF8) else 0 end )*(js.nnewbalancenum/abs(js.nnewbalancenum)) as 服务费 ,
js.ncostmny as 成本,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期,
substr((case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ),1,7) as 月份,
cu.sf as 省,
cu.cs as 市
from nc5x.so_squaredetail js
left join  nc5x.so_square zjs on js.csaleid = zjs.csaleid 
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,ch.unitweight,ch.unitvolume,cg.refsaleprice    as 批发售价,cg.def5 as 代理价 ,cg.lowestprice   as 最低限价
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
where 
length(cg.invcode) <> 4
and js.dr=0
and cg.width in ('兼容','原装','打印机')
and (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end)  not in ('孙希宝','张学兵','刘鱼浩','郑洁')
and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) >= '2022-01-01'
  )ma  where 市场部分配 not in ('线上业务','电商业务','客户业务') group by 月份,大类,存货名称,品牌,品类,小类,省

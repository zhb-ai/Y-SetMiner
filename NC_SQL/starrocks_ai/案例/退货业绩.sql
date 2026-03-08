select ma.主键,ma.客户名称,ma.业务员 ,ma.大类 ,count(distinct ma.日期)  ,sum(ma.流水) 流水 ,sum(ma.毛利) ,sum(ma.数量) 数量,sum(ma.硒鼓数量) 硒鼓数量,max(ma.日期),min(ma.日期) from (
select *
from(
select ma.主键, ma.客户编码,ma.客户名称,ma.存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,ma.是否赠品,ma.业务类型,ma.业务属性,ma.本币价税合计,ma.批发价税合计,ma.价税合计,ma.流水,ma.毛利,ma.成本,ma.市场部,ma.部门,ma.业务员,ma.日期,ma.省,ma.市
,substr(ma.日期,1,7) as 月份,ma.硒鼓数量
from  (select
js.ccustomerid 主键,
cu.custcode as 客户编码,
cu.custname as 客户名称,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
js.nnewbalancenum as 数量,
case when cg.width ='兼容' and cg.length like '%硒鼓%' then js.nnewbalancenum else 0 end 硒鼓数量 ,
js.blargessflag as 是否赠品,
yw.businame as 业务类型,
js.vdef11 as 业务属性,
case when js.blargessflag = 'Y' then 0 else js.nsummny end  as 本币价税合计 ,
js.nnewbalancenum*js.vbodydef5 as 批发价税合计,
(CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END) AS 价税合计,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end-js.ncostmny AS 毛利,
js.ncostmny as 成本,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期,
cu.sf as 省,
cu.cs as 市
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
where
  length(cg.invcode) <> 4
  and js.dr=0
  and '流水' <> 'null'
  --and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )   >= '2020-04-17'
  ) ma
   ) ma
  where   ma.大类  in ('兼容','原装','打印机')
  and 主键 in 
('1006C110000000ITKU2T',
'1006c110000000GLQOIW',
'1006C110000000AYHMYD',
'1006c110000000B6KY0T',
'1006c110000000GB27EF',
'1006c110000000GRTEGY')
   ) ma  group by ma.主键,ma.客户名称,ma.业务员 ,ma.大类
select * from nc5x.JS_SALES

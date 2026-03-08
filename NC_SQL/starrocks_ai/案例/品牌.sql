select ma.大类,
ma.品牌,
ma.品类分级
,ma.存货名称,ma.日期 ,
ma.品类,
ma.小类,
-- count(distinct ma.存货编码) 存货数量 ,
count(distinct ma.客户编码) 客户数量,
count(distinct ma.业务员)  业务员数量 ,
count(distinct ma.部门)  部门数量 ,
count(distinct ma.日期)  日期数量,
sum(ma.数量)  数量,
sum(ma.流水)  流水,
sum(ma.毛利)  毛利
from(
select  
substr(ma.日期,1,7) 月份,ma.pk_cumandoc,ma.客户编码,ma.客户名称,ma.存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,ma.是否赠品,ma.业务类型,ma.业务属性,ma.本币价税合计,ma.批发价税合计,ma.价税合计,ma.流水,ma.毛利,ma.成本,ma.市场部,ma.部门,ma.业务员,ma.日期,ma.省,ma.市,ma.库房
,case when ma.大类 = '兼容' and  ma.品类 = '硒鼓' and ma.小类 ='彩色' then '彩鼓'
when ma.大类 = '兼容' and  ma.品类 = '硒鼓' and ma.小类 ='黑色' then  '黑鼓' 
when ma.大类 = '兼容' and  ma.品类 = '碳粉' then '碳粉' 
when ma.大类 = '兼容' and  ma.品类 like '%标签%' then  '标签色带' 
when ma.大类 = '兼容' and  ma.品类 like '%色带%' then  '色带'
when ma.大类 = '兼容' and  ma.品类 like  '%复印%'  then  '复印类'
when ma.大类 = '兼容' and  ma.品类 like  '%墨水%'  then  '墨水'
when ma.大类 = '兼容' and  ma.品类 like  '%墨盒%'  then  '墨盒'
when ma.大类 = '兼容' and  ma.品类 like  '%碳带%'  then  '碳带' 
when ma.大类 = '原装' and  ma.品类 like  '%配件%'  then  '原装配件' 
when ma.大类 = '原装' and  ma.品类 like  '%复印%'  then  '复印类'
when ma.大类 = '原装' and  ma.品类 like  '%介质%'  then  '介质'
when ma.大类 = '原装' and  ma.品类 like  '%标签机色带%'  then  '标签色带'   
when ma.大类 = '原装' and  ma.品类 like  '%色带%'  then  '色带'
when ma.大类 = '原装' and  ma.品类 in ('硒鼓','粉仓') and ma.小类 ='彩色' then '彩鼓'
when ma.大类 = '原装' and  ma.品类 in ('硒鼓','粉仓') and ma.小类 ='黑色' then  '黑鼓' 
when ma.大类 = '原装' and  ma.品类 like  '%墨水%'  then  '墨水'
when ma.大类 = '原装' and  ma.品类 like  '%墨盒%'  then  '墨盒'
when ma.大类 = '打印机' and  ma.品类 like  '%针式打印机%'then  '针式打印机'
when ma.大类 = '打印机' and  ma.品类 like  '%打印%'and ma.小类 like '%渠道%' then  '渠道打印机'
when ma.大类 = '打印机' and  ma.品类 like  '%打印%'and ma.小类 like '%彩色%' then  '彩色打印机'
when ma.大类 = '打印机' and  ma.品类 like  '%打印%'and ma.小类 like '%黑白%' then  '黑白打印机'
when ma.大类 = '打印机' and  ma.品类 like  '%复合%'and ma.小类 like '%渠道%' then  '渠道复合机'
when ma.大类 = '打印机' and  ma.品类 like  '%复合%'and ma.小类 like '%行业%' then  '行业复合机'
when ma.大类 = '打印机' and  ma.品类 like  '%打印%'and ma.小类 like '%黑白%' then  '黑白打印机'
when ma.大类 = '打印机' and  ma.品类 like  '%喷墨%'and ma.小类 like '%渠道%' then  '渠道喷墨机'
when ma.大类 = '打印机' and  ma.品类 like  '%喷墨%'and ma.小类 like '%行业%' then  '行业喷墨机'
when ma.大类 = '打印机' and  ma.品类 like  '%激光%'and ma.小类 like '%渠道%' then  '渠道激光机'
when ma.大类 = '打印机' and  ma.品类 like  '%激光%'and ma.小类 like '%行业%' then  '行业激光机'
when ma.大类 = '打印机' and  ma.品类 like  '%扫描仪%' then  '扫描仪'
when ma.大类 = '打印机' and  ma.品类 like  '%传真机%' then  '传真机'
when ma.大类 = '打印机' and  ma.品类 like  '%配件%' then  '打印机配件'
end  品类分级
from 
(select 
cu.pk_cumandoc,
cu.custcode as 客户编码,
cu.custname as 客户名称,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类, 
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
 ck.storname as 库房,
js.nnewbalancenum as 数量,
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
  left join nc5x.bd_stordoc ck
    on js.cwarehouseid = ck.pk_stordoc
where 
  length(cg.invcode) <> 4
  and js.dr=0
  and '流水' <> 'null'
  and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )   >= '2020-04-17'
  )ma
   )ma
  where ma.日期 between '2021-06-01'and '2021-06-30' 
  and ma.大类 in ('兼容') --and ma.品牌='联想' and ma.品类='粉仓' and  ma.小类= '打印类'
  group by  ma.大类,ma.品牌, ma.品类分级 ,ma.小类,ma.品类,ma.存货名称,ma.日期
 

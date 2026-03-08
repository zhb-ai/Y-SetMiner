select ma.库房,ma.业务员,ma.部门,ma.大类,ma.品牌,ma.月份,sum(ma.流水)   from (
select ma.库房,ma.客户编码,ma.客户名称,ma.存货编码,ma.存货名称,ma.单据号,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,ma.是否赠品,ma.市场部,ma.部门,ma.业务员,to_date(ma.日期,'yyyy-MM-dd') as 日期,ma.流水,ma.毛利,ma.省,ma.市,
case when substr(ma.日期,6,2)='01' then '1月'
 when substr(ma.日期,6,2)='02' then '2月'
    when substr(ma.日期,6,2)='03' then '3月'
       when substr(ma.日期,6,2)='04' then '4月'  
          when substr(ma.日期,6,2)='05' then '5月'
           when substr(ma.日期,6,2)='06' then '6月'
              when substr(ma.日期,6,2)='07' then '7月'
                 when substr(ma.日期,6,2)='08' then '8月'
                    when substr(ma.日期,6,2)='09' then '9月'  
                       when substr(ma.日期,6,2)='10' then '10月'
                          when substr(ma.日期,6,2)='11' then '11月'
                             when substr(ma.日期,6,2)='12' then '12月' end 月份,
          case when substr(ma.日期,1,4)='2019'  then '2019'
           when substr(ma.日期,1,4)='2020'  then '2020' end   年份,
            case when ma.品牌 like '%扬帆耐立%'or ma.品牌 like '%盈佳%' then '高端'
              when ma.品牌 like '%智通%'then '中高'
                when ma.品牌 like '%懿%' or  ma.品牌 like '%方格%' then '中低' end 品牌分级,
            case when ma.品牌 like '%扬帆耐立%'or ma.品牌 like '%盈佳%'or  ma.品牌 like '%智通%'or  ma.品牌 like '%方格%' then '线上'
                when ma.品牌 like '%懿智通%'  then '代理商'
                   when ma.品牌 like '%懿品%'  then '线下' 
                  end 渠道,
                  case when ma.品牌 like '%扬帆耐立%' then '扬帆耐立'
                  when  ma.品牌 like '%盈佳%'then '盈佳' 
                   when   ma.品牌 like '智通%'then  '智通'
                      when   ma.品牌 like '%方格%' then '方格博士'
                when ma.品牌 like '%懿智通%'  then '懿智通'
                   when ma.品牌 ='懿品'  then '懿品' 
                       when ma.品牌 like '%懿品佳%'then '懿品佳' 
                  end 品牌一
from ( select 
cu.custname as 客户名称,
custcode 客户编码 ,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
yw.busicode as 业务类型,
js.nnewbalancenum as 数量,
js.blargessflag as 是否赠品,
js.vreceiptcode 单据号,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期,
 js.vdef11 as 业务属性,
  js.nsummny  as 本币价税合计,
  js.nnewbalancenum*js.vbodydef5 as 批发价税合计,
  (CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END) AS 价税合计,
  ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2) AS 流水,
  ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)-js.ncostmny AS 毛利,
js.ncostmny as 成本,
cu.sf as 省,
cu.cs as 市,
ck.storname as 库房
from nc5x.so_squaredetail js
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
from nc5x.bd_invmandoc cg
join nc5x.bd_invbasdoc ch
on cg.pk_invbasdoc = ch.pk_invbasdoc)cg
on js.cinventoryid = cg.pk_invmandoc
LEFT join nc5x.bd_busitype yw
on js.cbiztype = yw.pk_busitype
LEFT join nc5x.v_zlw_cust cu
on js.ccustomerid = cu.pk_cumandoc
left join nc5x.bd_psndoc us
on us.pk_psndoc= js.cemployeeid
 left join nc5x.bd_stordoc ck
    on js.cwarehouseid = ck.pk_stordoc
where            
  cg.invcode <> '9805'
  and cg.invcode <> '9810'
  and cg.invcode <> '9807'
  and cg.invcode <> '9809'
  and cg.invcode <> '9899'
  and cg.invcode <> '9898'
  --and yw.busicode = 's005'
  --and js.vreceiptcode  = 'SO2004170427'
  and js.dr=0 --AND  cg.invpinpai like '%懿品佳%' and (cg.invname like '%CF40%'OR cg.invname like '%CF41%'OR cg.invname like '%CF50%'OR cg.invname like '%CF51%')
  and '流水' <> 'null'
  )ma 
 --and ma.存货名称 LIKE '%921%'          
where (SUBSTR(ma.日期,1,10) between  '2020-09-01'and '2020-10-31') and  ma.库房 like'%成都%'
--and ma.大类='兼容'
--and  (ma.库房 like '%成都%' or  ma.库房 like '%重%' or  ma.库房 like '%哈尔滨%'or ma.库房 like '%南%'or  ma.库房 like '%沈%')
--and ma.品类 like '%复印%'and ma.大类='兼容' and  ma.业务员='陈宇'
 )ma group by  ma.库房,ma.月份,ma.业务员,ma.部门,ma.大类,ma.品牌

 --and  ma.大类 ='兼容'and ma.品类 like '%复印%'
    --and (ma.品牌 like '%扬帆耐立%'or ma.品牌 like '%盈佳%')and ma.存货名称 like '%CE74%'


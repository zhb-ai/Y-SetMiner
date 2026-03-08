
SELECT ma.业务员,ma.客户名称,ma.市场部,ma.部门,sum(ma.数量),SUM(ma.流水),SUM(ma.本币价税合计),SUM(ma.毛利),ma.省,ma.市,ma.品牌,ma.大类,ma.品类,ma.日期,ma.月份,ma.年份 ,ma.客户编码,ma.是否放货,ma.代理商 from (
select 
ma.业务员,ma.客户名称,ma.客户编码,ma.市场部,ma.部门,ma.数量,ma.流水,ma.本币价税合计,ma.毛利,ma.省,ma.市,ma.品牌,ma.大类,ma.品类,to_date(ma.日期,'yyyy-MM-dd') as 日期,case when substr(ma.日期,6,2)='01' then '1月'
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
  when substr(ma.日期,1,4)='2020'  then '2020' end 年份,ma.是否放货   ,
       case when   ma.客户编码 in ('15188230168',
'18637009288',
'18088621233',
'13359179552',
'18009017631',
'13939679621',
'15539599896',
'FP-18137277372',
'18220290546',
'13624810069',
'18843994881',
'13808957511',
'18791289991',
'18085002519',
'13756003044',
'13589770099',
'13309101509',
'15247958981',
'13864718919',
'13350290368',
'18113383325',
'15176940088',
'15035979605',
'18663295527',
'13350947957',
'18940506036',
'85833133',
'0831-8218208',
'15248885999',
'13773339931',
'13474567460',
'18693701273',
'13166557188',
'13808237488',
'FP-13889139977',
'13848935710',
'13513538049',
'13904796934',
'15615605578',
'13151895822',
'13359916333',
'04192155601',
'015840144427',
'13808080405',
'15041899666',
'13704774523',
'13880111119',
'0518-87223350',
'15062920170',
'57815513',
'18914951191',
'13506881278',
'18697231353',
'04540011',
'FP-15144029112',
'FP-15042072888',
'13615184878',
'13906384116',
'18931793527',
'15044718866',
'013903189910',
'13770024072',
'17699912435',
'FP-15981649669',
'13898523230',
'13188591916',
'13961500178',
'18683099990',
'15086614981',
'18793575500',
'07158258258',
'18642136677',
'13889139977',
'13019361518') then '懿智通代理' 
when    ma.客户编码    in ('13171208635',
'13562283286',
'13964835508',
'FP-13964835508',
'85615170',
'18535114477',
'13833307755',
'13218572852',
'18651825037',
'18951288803',
'13984118239',
'13082161505',
'13609323899',
'15165616667',
'13820672669',
'15100195896',
'13582850140',
'18526508729',
'15320169639',
'15320077800',
'13802191109',
'13802053869',
'13820494543',
'13789667610',
'13821879456',
'018611171829',
'13880642570',
'13393496558',
'18220336555',
'13609323899',
'15829995220',
'13897310396',
'FP-13180818654',
'13820007988',
'13309532121') then '懿品代理' else null end 代理商      
from ( select       
cu.custname as 客户名称,
custcode 客户编码 ,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.lowestprice 最低限价,
cg.refsaleprice 批发价,
cg.invpinpai as 品牌,
cg.height as 小类,
yw.busicode as 业务类型,
js.nnewbalancenum as 数量,
js.blargessflag as 是否赠品,
js.vreceiptcode 单据号,
cu.deptname as 市场部,
cu.def3 是否商桥,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期,
 js.vdef11 as 业务属性,
case when js.blargessflag = 'Y' then 0 else js.nsummny end  as 本币价税合计,
js.nnewbalancenum*js.vbodydef5 as 批发价税合计,
case when js.blargessflag = 'Y' then 0 else js.nsummny/js.nnewbalancenum end  as 单价,
(CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END) AS 价税合计,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end-js.ncostmny AS 毛利,
js.ncostmny as 成本,
  cu.sf as 省,
cu.cs as 市 ,
 ck.storname as 出库仓库 ,
 case when  yw.busicode = 's005' then '放货'
 else '销售'end 是否放货 ,
 case when  cg.def3 like '%套%' then '成套' else  null  end as 是否成套

from nc5x.so_squaredetail js
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,cg.lowestprice,cg.refsaleprice , cg.def3
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
 --and yw.busicode <> 's005'
  --and js.vreceiptcode  = 'SO2004170427'
  and js.dr=0
  and '流水' <> 'null' 
  )ma
 --and ma.存货名称 LIKE '%921%'
--and to_char(sysdate,'yyyy-mm-dd') 
 where
SUBSTR(ma.日期,1,10) =to_char(sysdate-1,'yyyy-mm-dd') )ma  group by  ma.业务员,ma.代理商,ma.客户名称,ma.市场部,ma.部门,ma.省,ma.市,ma.品牌,ma.大类,ma.品类,ma.日期,ma.月份,ma.年份,ma.客户编码,ma.是否放货 order by ma.客户名称,ma.客户编码,ma.省,ma.市

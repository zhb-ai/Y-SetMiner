select c.psnname,c.custname,c.区域,d.* from (select c.*,case when c.psnname ='但波' then '贵州'
                when c.psnname ='杨守情'then '河南'
                 when c.psnname ='张贺龙'then '吉林'
                    when c.psnname ='孟庆伟'then '内蒙古'
                       when c.psnname ='余国永'then '青海'
                          when c.psnname ='彭世烨'then '陕西'
                             when c.psnname ='范增'then '沈阳办公'
                              when c.psnname ='闫广军'then '沈阳办公'end 区域
    from nc5x.v_zlw_cust  c --and  c.linkman1 is not null
    
    )c   join 

(select ma.客户名称,ma.存货编码,ma.存货名称,ma.单据号,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,ma.是否赠品,ma.市场部,ma.部门,ma.业务员,to_date(ma.日期,'yyyy-MM-dd') as 日期,ma.流水,ma.毛利,ma.省,ma.市,case when substr(ma.日期,6,2)='01' then '1月'
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
           when substr(ma.日期,1,4)='2020'  then '2020' end 年份
             ,case when ma.业务员 ='但波' then '贵州'
                when ma.业务员  ='杨守情'then '河南'
                 when ma.业务员 ='张贺龙'then '吉林'
                    when ma.业务员 ='孟庆伟'then '内蒙古'
                       when ma.业务员 ='余国永'then '青海'
                          when ma.业务员 ='彭世烨'then '陕西'
                             when ma.业务员 ='范增'then '沈阳办公'
                              when ma.业务员 ='闫广军'then '沈阳办公'end 区域
--case when substr(to_date(ma.日期,'yyyy-MM-dd'),6,2)=03 then '3月'
--when substr(to_date(ma.日期,'yyyy-MM-dd'),6,2)=04 then '4月' end 月份
from (select 
cu.custname as 客户名称,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
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
  js.ncostmny as 成本
  ,cu.sf as 省,
cu.cs as 市 
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
where            
  cg.invcode <> '9805'
  and cg.invcode <> '9810'
  and cg.invcode <> '9807'
  and cg.invcode <> '9809'
  and cg.invcode <> '9899'
 -- and yw.busicode <> 's005'
  and js.dr=0
  and '流水' <> 'null')ma
where  
--
--and ma.存货名称 LIKE '%921%'
SUBSTR(ma.日期,1,10) between  '2020-09-01'and '2020-09-31'and ma.部门 like '%南京%') d on d.客户名称=c.custname

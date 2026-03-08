SELECT * FROM (
select 
(CASE cu.deptname 
WHEN '渠道部' THEN cu.psnname 
WHEN '外埠市场部' THEN cu.psnname 
WHEN '北京市场部' THEN cu.psnname

ELSE(CASE cu.n_deptname
WHEN '南京雄狮' THEN cu.psnname 
  WHEN '西安科贸' THEN cu.psnname
WHEN '大客户部' THEN cu.n_deptname
WHEN '客户部' THEN cu.n_deptname
WHEN '公交集团业务部' THEN cu.n_deptname
WHEN '采购部' THEN cu.n_deptname
WHEN '项目部' then cu.n_deptname
when '淘宝直营' THEN '线上营销部'
when '京东-扬帆耐立' THEN '线上营销部' 
when '洋帆-淘宝旗舰店' THEN '线上营销部' 
WHEN '天猫-世纪华商' THEN '线上营销部' 
when '天猫-智通仁和' THEN '线上营销部' 
WHEN '拼多多方格博士店' THEN '线上营销部' 
when '渠道256' THEN '线上营销部' 
when '苏宁业务部' THEN  '苏宁业务部'
WHEN '京东慧采业务部' THEN '京东慧采业务部'
WHEN '京东仁和大客户部'  THEN  '京东仁和大客户部'
WHEN '京东耐力大客户部'  THEN  '京东耐力大客户部'
  
ELSE cu.n_deptname END) END)as 部门,
  
(CASE 
WHEN cu.psnname='南京雄狮-蒋继欣'  THEN '渠道部'
WHEN cu.deptname ='渠道部' THEN '渠道部' 
WHEN cu.deptname = '北京市场部' THEN '北京市场部' 
WHEN cu.deptname ='外阜市场部' THEN '外埠市场部' 

ELSE
( CASE cu.n_deptname
WHEN '大客户部' THEN '客户业务' 
WHEN '客户部' THEN '客户业务' 
WHEN '公交集团业务部' THEN '客户业务' 
WHEN '采购部' THEN '客户业务' 
WHEN '项目部' then ' 客户业务' 
when '淘宝直营' THEN '线上'
when '京东-扬帆耐立' THEN '线上' 
when '洋帆-淘宝旗舰店' THEN '线上' 
WHEN '天猫-世纪华商' THEN '线上' 
when '天猫-智通仁和' THEN '线上' 
WHEN '拼多多方格博士店' THEN '线上' 
when '渠道256' THEN '线上' 
when '苏宁业务部' THEN  '线上'
WHEN '京东慧采业务部' THEN '线上'
WHEN '京东仁和大客户部'  THEN '线上'
WHEN '京东耐力大客户部'  THEN '线上'
    
ELSE '其他' end) END ) AS 市场部,

SUM(case when cg.width<>'兼容' then 0 else (CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END)END) AS 兼容价税合计,
SUM(case when cg.width not in('原装','打印机') then 0 else (CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END)END) AS 原装价税合计

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
where js.dmakedate >= TO_CHAR(sysdate-31,'yyyy-mm-dd')
  and js.dmakedate <= TO_CHAR(sysdate-1,'yyyy-mm-dd')
  and cg.invcode <> '9805'
  and cg.invcode <> '9810'
  and cg.invcode <> '9807'
  and cg.invcode <> '9809'
  and cg.invcode <> '9899'
  and js.dr=0
  and yw.busicode <> 's005'
  and '流水' <> 'null'
GROUP BY 
(CASE cu.deptname 
WHEN '渠道部' THEN cu.psnname 
WHEN '外埠市场部' THEN cu.psnname 
WHEN '北京市场部' THEN cu.psnname
 
ELSE(CASE cu.n_deptname
WHEN '南京雄狮' THEN cu.psnname 
  WHEN '西安科贸' THEN cu.psnname
WHEN '大客户部' THEN cu.n_deptname
WHEN '客户部' THEN cu.n_deptname
WHEN '公交集团业务部' THEN cu.n_deptname
WHEN '采购部' THEN cu.n_deptname
WHEN '项目部' then cu.n_deptname
when '淘宝直营' THEN '线上营销部'
when '京东-扬帆耐立' THEN '线上营销部' 
when '洋帆-淘宝旗舰店' THEN '线上营销部' 
WHEN '天猫-世纪华商' THEN '线上营销部' 
when '天猫-智通仁和' THEN '线上营销部' 
WHEN '拼多多方格博士店' THEN '线上营销部' 
when '渠道256' THEN '线上营销部' 
when '苏宁业务部' THEN  '苏宁业务部'
WHEN '京东慧采业务部' THEN '京东慧采业务部'
WHEN '京东仁和大客户部'  THEN  '京东仁和大客户部'
WHEN '京东耐力大客户部'  THEN  '京东耐力大客户部'
  
ELSE cu.n_deptname END) END),
(CASE 
WHEN cu.psnname='南京雄狮-蒋继欣'  THEN '渠道部'
WHEN cu.deptname ='渠道部' THEN '渠道部' 
WHEN cu.deptname = '北京市场部' THEN '北京市场部' 
WHEN cu.deptname ='外阜市场部' THEN '外埠市场部' 

ELSE
( CASE cu.n_deptname
WHEN '大客户部' THEN '客户业务' 
WHEN '客户部' THEN '客户业务' 
WHEN '公交集团业务部' THEN '客户业务' 
WHEN '采购部' THEN '客户业务' 
WHEN '项目部' then ' 客户业务' 
when '淘宝直营' THEN '线上'
when '京东-扬帆耐立' THEN '线上' 
when '洋帆-淘宝旗舰店' THEN '线上' 
WHEN '天猫-世纪华商' THEN '线上' 
when '天猫-智通仁和' THEN '线上' 
WHEN '拼多多方格博士店' THEN '线上' 
when '渠道256' THEN '线上' 
when '苏宁业务部' THEN  '线上'
WHEN '京东慧采业务部' THEN '线上'
WHEN '京东仁和大客户部'  THEN '线上'
WHEN '京东耐力大客户部'  THEN '线上'
  
ELSE '其他' end) END )
) a where 市场部 in ('外埠市场部','北京市场部','渠道部') or 部门 in('大客户部') order by 2,1

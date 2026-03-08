select ma.客户主键,ma.日期,ma.打印品牌,ma.大类,ma.部门,ma.部门划分,ma.客户名称,ma.业务员,sum(ma.流水) as 流水,sum(ma.毛利) as 毛利 ,sum(ma.数量) as 数量  ,
case when ma.打印品牌 in ('佳能硒鼓','利盟') then '李欣宇'
when ma.打印品牌 in ('爱普生打印机','佳能打印机','惠普打印机（渠道）','其它品牌打印机','惠普打印机（行业）') then '何路超'
  when ma.打印品牌 in ('三星','OKI','施乐','兄弟','富士通','联想') then '于志永'
      when ma.打印品牌 in ('奔图打印机','奔图','华为打印机','立思辰') then '李晶伟'
    when ma.打印品牌  in ('惠普黑鼓') then '李亨熠'
      when  ma.打印品牌 ='其它打印类' then '石鑫鑫'
         when ma.打印品牌 in ('三星复印类','柯尼卡美能达','京瓷') then '任彬硕'
         when ma.打印品牌 in ('佳能复印类','施乐复印类','东芝','夏普','理光','其他复印类') then '李利强'
          when ma.打印品牌 in ('爱普生','惠普墨盒','佳能墨盒') then '张京'
            when ma.打印品牌 in ('惠普彩鼓') then '姚辉铭'
               when ma.打印品牌 in ('扬帆耐立','智通') then '张曦'
        when ma.打印品牌 in ('盈佳') then '苗凯'
                   when ma.打印品牌 in ('懿品','懿智通','方格博士','懿品佳') then '张鹏鹏' else '分组异常' end 负责人
           
 from (
select ma.客户主键, ma.客户编码,ma.客户名称,ma.存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,ma.是否赠品,ma.业务类型,ma.业务属性,ma.本币价税合计,ma.批发价税合计,ma.价税合计,ma.流水,ma.毛利,ma.成本,ma.市场部,ma.部门,ma.业务员,ma.日期,ma.省,ma.市,ma.库房
, case when ma.大类 ='打印机' and ma.品牌 = '爱普生' then '爱普生打印机'
when ma.大类 ='打印机' and ma.品牌 like  '%佳能%' then '佳能打印机'
when ma.大类 ='打印机' and ma.品牌 = '奔图'then '奔图打印机'
when ma.大类 ='打印机' and ma.品牌 like '%华为%'  then '华为打印机'
when ma.大类 ='打印机' and ma.品牌 like '%惠普%' and ma.小类 = '行业' then '惠普打印机（行业）'
when ma.大类 ='打印机' and ma.品牌 like '%惠普%'  and ma.小类 = '渠道' then '惠普打印机（渠道）'
when ma.大类 ='打印机' then '其它品牌打印机'
when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '硒鼓','配件') and ma.小类 = '彩色' then '惠普彩鼓'
when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '硒鼓','配件') and ma.小类 = '黑色' then '惠普黑鼓'
when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '墨盒','墨水','介质')  then '惠普墨盒'
when   ma.大类 ='原装' and ma.品牌 = '三星' and ma.品类 in ( '粉仓','硒鼓')  then '三星'
when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '墨盒','墨水','介质')  then '佳能墨盒'
when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '硒鼓','粉仓','配件')  then '佳能硒鼓'
when   ma.大类 ='原装' and ma.品牌 = '施乐' and ma.品类 in ( '硒鼓','粉仓')  then '施乐'
when   ma.大类 ='原装' and ma.品牌 = '奔图' then '奔图'
when   ma.大类 ='原装' and ma.品牌 = '兄弟' then '兄弟'
when   ma.大类 ='原装' and ma.品牌 = '华为' then '华为'
when   ma.大类 ='原装' and ma.品牌 = '立思辰' then '立思辰'
when   ma.大类 ='原装' and ma.品牌 = '富士通' then '富士通'
when   ma.大类 ='原装' and ma.品牌 = 'OKI' then 'OKI'
when   ma.大类 ='原装' and ma.品牌 = '联想' then '联想'
when   ma.大类 ='原装' and ma.品牌 = '爱普生' then '爱普生'
when   ma.大类 ='原装' and ma.品牌 = '利盟' then '利盟'
when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '佳能复印类'
when   ma.大类 ='原装' and ma.品牌 = '施乐' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '施乐复印类'
when   ma.大类 ='原装' and ma.品牌 = '三星' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '三星复印类'
when   ma.大类 ='原装' and ma.品牌 in ('柯尼卡美能达','德凡')   then '柯尼卡美能达'
when   ma.大类 ='原装' and ma.品牌 in ('东芝')   then '东芝'
when   ma.大类 ='原装' and ma.品牌 in ('夏普')   then '夏普'
when   ma.大类 ='原装' and ma.品牌 in ('理光')   then '理光'
when   ma.大类 ='原装' and ma.品牌 in ('京瓷')   then '京瓷'
when   ma.大类 ='原装' and ma.品牌 in ('理想','震旦','松下')   then '其他复印类'
when   ma.大类 ='原装'  then '其它打印类'
when   ma.大类 ='兼容' and ma.品牌 = '懿品' then '懿品'
when   ma.大类 ='兼容' and ma.品牌 = '懿品佳' then '懿品佳'
when   ma.大类 ='兼容' and ma.品牌 = '懿品佳复印' then '懿品佳'
when   ma.大类 ='兼容' and ma.品牌 like '方格博士%' then '方格博士'
when   ma.大类 ='兼容' and ma.品牌 like '懿智通%' then '懿智通'
when   ma.大类 ='兼容' and ma.品牌 like '盈佳%' then '盈佳'
when   ma.大类 ='兼容' and ma.品牌 like '扬帆耐立%' then '扬帆耐立'
when   ma.大类 ='兼容' and ma.品牌 like '耐力%' then '扬帆耐立'
when   ma.大类 ='兼容' and ma.品牌 like '智通%' then '智通'
when   ma.大类 ='兼容' and ma.品牌 like '%网络%' then '兼容网络版'
 else '其他-异常'end  打印品牌,
                                                                                 
 case when    ma.部门 in ('京东-扬帆耐立',
'京东仁和POP店',
'京东自营盈佳店',
'京东自营耐力店',
'京喜-智通仁和',
'天猫-世纪华商',
'天猫-企业购',
'天猫-智通仁和',
'拼多多-佳能专卖',
'拼多多-办公专营',
'拼多多-惠普专卖',
'拼多多-方格博士',
'淘宝-扬帆耗材',
'淘宝直营') then '线上C端'
when ma.部门  in ('京东慧采仁和',
'京东慧采耐力','京喜-世纪华商') then '慧采'
else '其他' end 部门划分                                                                                                                              
from (select
cu.pk_cubasdoc 客户主键,
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
        from nc5x.bd_invmandoc  cg
        join nc5x.bd_invbasdoc  ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc ) cg
on js.cinventoryid = cg.pk_invmandoc
LEFT join nc5x.bd_busitype   yw
on js.cbiztype = yw.pk_busitype
LEFT join nc5x.v_zlw_cust   cu
on js.ccustomerid = cu.pk_cumandoc
left join nc5x.bd_psndoc  us
on us.pk_psndoc= js.cemployeeid
  left join nc5x.bd_stordoc ck
    on js.cwarehouseid = ck.pk_stordoc
where
  length(cg.invcode)  <>  4
  and js.dr = 0
  and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) >=  to_char( sysdate - 5,'yyyy-mm-dd') 
  ) ma where ma.大类 in ('打印机','原装','兼容')) ma
   group by ma.客户主键 , ma.打印品牌,ma.大类,ma.部门划分,ma.客户名称,ma.业务员,ma.日期,ma.部门
  
  

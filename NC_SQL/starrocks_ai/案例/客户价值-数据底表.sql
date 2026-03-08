select * from (
select cu.市场部,cu.部门 ,cu.业务员 ,cu.客户编码 ,cu.客户名称 ,cu.额度,cu.账期,cu.放货额度,cu.放货账期,cu.客户主键,nvl(a.主客户主键,cu.客户主键) 主客户主键,cu.商桥 
from (SELECT cum.deptname as 市场部,cum.n_deptname as 部门,cum.psnname as 业务员,dq.sf as 省份,dq.cs as 城市,
(case when (cum.sealflag is not null or length(ltrim(rtrim(cum.sealflag))) > 0 ) then 'Y' ELSE 'N' END ) as 是否封存,
(case when cub.def3 = '0001C11000000012TJ3X' then '商桥' else '' end) as 商桥,
cub.custcode as 客户编码,cub.custname as 客户名称,
redit.nlimitmny as 额度,
(case when cum.termid = '01' then 0 else to_number(cum.termid) end ) as 账期,
redits.nlimitmny as 放货额度,
cum.innerctldays as 放货账期,
cub.pk_cubasdoc as 客户主键,
cum.pk_cumandoc
FROM nc5x.bd_cubasdoc cub
join (select substr(deptcode,1,4) deptcode,
(case
when substr(dept.deptcode, 1, 6) in ( '030400','030441')  then
'区域销售部'
when substr(dept.deptcode, 1, 4) = '0303' then
'北京市场部'
when substr(dept.deptcode, 1, 4) = '0304' then
'外阜市场部'
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
and cum.dr = 0)cum
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
where   (case when (cum.sealflag is not null or length(ltrim(rtrim(cum.sealflag))) > 0 ) then 'Y' ELSE 'N' END )  ='N'
and cum.deptname <>  '直营+微分销' and cum.psnname not in ('管理员','共享客户')  )  cu
left join 
(select distinct cuc.pk_cumandoc 子客户主键 ,cuml.主客户主键
from nc5x.bd_cubasdoc cum   join 
(select   pk_cubasdoc 子客户主键,custcode 子客户编码,custname  子客户名称,pk_cubasdoc1 主客户主键    from nc5x.bd_cubasdoc  where  pk_cubasdoc1 is not null ) cuml 
on cuml.子客户主键= cum.pk_cubasdoc 
left join 
 nc5x.bd_cumandoc cuc
on cum.pk_cubasdoc = cuc.pk_cubasdoc and cum.dr = 0) a on cu.pk_cumandoc = a.子客户主键 ) cu
left join 
(select 主客户主键,
sum(兼容流水)兼容流水,
sum(原装流水)原装流水,
sum(打印机流水)打印机流水,
sum(原装毛利)原装毛利,
sum(兼容毛利)兼容毛利,
sum(打印机毛利)打印机毛利,
sum(华为PC产品线流水)华为PC产品线流水,
sum(华为PC产品线毛利)华为PC产品线毛利
 from (
select 兼容流水,兼容毛利,原装流水,原装毛利,打印机流水,打印机毛利,华为PC产品线流水,华为PC产品线毛利,nvl(主客户主键,客户主键)主客户主键  from 
(select 客户主键,
sum(case when ma.大类 = '兼容' then 流水 else 0 end) 兼容流水,
sum(case when ma.大类 = '兼容' then 毛利 else 0 end) 兼容毛利,
sum(case when ma.大类 in ('原装') then 流水 else 0 end) 原装流水,
sum(case when ma.大类 in ('原装') then 毛利 else 0 end) 原装毛利,
sum(case when ma.大类 in ('打印机','智能家居') then 流水 else 0 end) 打印机流水,
sum(case when ma.大类 in ('打印机','智能家居') then 毛利 else 0 end) 打印机毛利,
sum(case when ma.大类 in ('电脑PC') and 品牌 = '华为' then 流水 else 0 end) 华为PC产品线流水,
sum(case when ma.大类 in ('电脑PC') and 品牌 = '华为' then 毛利 else 0 end) 华为PC产品线毛利
from (select
cu.pk_cubasdoc 客户主键,
js.vdef8,
js.vreceiptcode,
js.cbodywarehouseid ,
js.ccustomerid 主键,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
js.nnewbalancenum as 数量,
js.blargessflag as 是否赠品,
js.vdef11 as 业务属性,
(CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END) AS 价税合计,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end-js.ncostmny AS 毛利,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期
from nc5x.so_squaredetail js
left join  nc5x.so_square zjs on js.csaleid = zjs.csaleid 
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,ch.unitweight,ch.unitvolume,cg.refsaleprice    as 批发售价,cg.def5 as 代理价 ,cg.lowestprice   as 最低限价
from nc5x.bd_invmandoc cg
join nc5x.bd_invbasdoc ch
on cg.pk_invbasdoc = ch.pk_invbasdoc )cg
on js.cinventoryid = cg.pk_invmandoc
LEFT join nc5x.v_zlw_cust  cu
on js.ccustomerid = cu.pk_cumandoc
where 
length(cg.invcode) <> 4
and js.dr=0
and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) >= to_char (sysdate-181,'yyyy-mm-dd')
) ma  group by 客户主键    
) js 
left join 
(select distinct cuml.子客户主键,cuml.主客户主键
from nc5x.bd_cubasdoc cum   join 
(select   pk_cubasdoc 子客户主键,custcode 子客户编码,custname  子客户名称,pk_cubasdoc1 主客户主键    from nc5x.bd_cubasdoc  where  pk_cubasdoc1 is not null ) cuml 
on cuml.子客户主键= cum.pk_cubasdoc 
left join 
nc5x.bd_cumandoc cuc
on cum.pk_cubasdoc = cuc.pk_cubasdoc and cum.dr = 0 )  cus
on cus.子客户主键 = js.客户主键) group by 主客户主键 ) js
on cu.主客户主键 = js.主客户主键 
left join (
select  
主客户主键
,sum(兼容流水)出货兼容流水
,sum(原装流水)出货原装流水
,sum(放货流水)放货流水 
,sum(打印机流水)打印机流水
,count(distinct 日期)提货频次
,181/count(distinct 日期) 提货周期 
,max(日期)最后交易日期
,min(日期)首次交易日期
,sum(一月兼容流水) 一月兼容流水
,sum(二月兼容流水) 二月兼容流水
,sum(三月兼容流水) 三月兼容流水
,sum(四月兼容流水) 四月兼容流水
,sum(五月兼容流水) 五月兼容流水
,sum(六月兼容流水) 六月兼容流水
,sum(近三月商桥下单流水) 近三月商桥下单流水
,sum(近三月华为PC产品线流水) 近三月华为PC产品线流水
,sum(近三月奔图国产化流水) 近三月奔图国产化流水
 from  
( select 
cu.pk_cubasdoc 客户主键,
nvl(cus.主客户主键,cu.pk_cubasdoc) 主客户主键,
ii.dbilldate 日期,
case when ib.width  = '兼容' and ii.dbilldate >= to_char (sysdate-91,'yyyy-mm-dd') then ib.noriginalcurmny else 0 end  兼容流水,
case when ib.width  in ('原装') and ii.dbilldate >= to_char (sysdate-91,'yyyy-mm-dd') then ib.noriginalcurmny else 0 end 原装流水,
case when ib.width  in ('打印机','智能家居') and ii.dbilldate >= to_char (sysdate-91,'yyyy-mm-dd') then ib.noriginalcurmny else 0 end 打印机流水,
case when ib.width  = '兼容' and ii.dbilldate between to_char (sysdate-181,'yyyy-mm-dd') and to_char (sysdate-152,'yyyy-mm-dd')  then ib.noriginalcurmny else 0 end 一月兼容流水,
case when ib.width  = '兼容' and ii.dbilldate between to_char (sysdate-151,'yyyy-mm-dd') and to_char (sysdate-122,'yyyy-mm-dd')  then ib.noriginalcurmny else 0 end 二月兼容流水,
case when ib.width  = '兼容' and ii.dbilldate between to_char (sysdate-121,'yyyy-mm-dd') and to_char (sysdate-92,'yyyy-mm-dd')  then ib.noriginalcurmny else 0 end 三月兼容流水,
case when ib.width  = '兼容' and ii.dbilldate between to_char (sysdate-91,'yyyy-mm-dd') and to_char (sysdate-62,'yyyy-mm-dd')  then ib.noriginalcurmny else 0 end 四月兼容流水,
case when ib.width  = '兼容' and ii.dbilldate between to_char (sysdate-61,'yyyy-mm-dd') and to_char (sysdate-32,'yyyy-mm-dd')  then ib.noriginalcurmny else 0 end 五月兼容流水,
case when ib.width  = '兼容' and ii.dbilldate between to_char (sysdate-31,'yyyy-mm-dd') and to_char (sysdate-2,'yyyy-mm-dd')  then ib.noriginalcurmny else 0 end 六月兼容流水,
case when yw.busicode = 's005' and ii.dbilldate >= to_char (sysdate-181,'yyyy-mm-dd')  then ib.noriginalcurmny else 0 end 放货流水 ,
case when m.VDEF16 = 'SQ'and ii.dbilldate >= to_char (sysdate-91,'yyyy-mm-dd')  then ib.noriginalcurmny else 0 end 近三月商桥下单流水,
case when ib.width  in ('电脑PC') and invpinpai = '华为' and ii.dbilldate >= to_char (sysdate-91,'yyyy-mm-dd')  then ib.noriginalcurmny else 0 end  近三月华为PC产品线流水,
case when ib.width  in ('原装') and invpinpai in ('华讯安信翼','汉光','奔图','立思辰','光电通','方正','长城','爱胜品','得力') and ii.dbilldate >= to_char (sysdate-91,'yyyy-mm-dd') then ib.noriginalcurmny else 0 end 近三月奔图国产化流水,
ib.noriginalcurmny as 流水,
case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
from nc5x.so_saleinvoice ii
left  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode, ib.noriginalcurmny,
ch.unitvolume ,
ch.unitweight 
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc
) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu 
on ii.creceiptcorpid  = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_stordoc dd
on ii.cwarehouseid = dd.pk_stordoc
left  join  nc5x.so_sale m 
on ib.coriginalbillcode = m.vreceiptcode
left join nc5x.sm_user w
on m.coperatorid =w.cuserid
left join nc5x.bd_psndoc  us
on us.pk_psndoc= ii.cemployeeid
left join 
(select distinct cuml.子客户主键,cuml.主客户主键
from nc5x.bd_cubasdoc cum   join 
(select   pk_cubasdoc 子客户主键,custcode 子客户编码,custname  子客户名称,pk_cubasdoc1 主客户主键    from nc5x.bd_cubasdoc  where  pk_cubasdoc1 is not null ) cuml 
on cuml.子客户主键= cum.pk_cubasdoc 
left join 
nc5x.bd_cumandoc cuc
on cum.pk_cubasdoc = cuc.pk_cubasdoc and cum.dr = 0 )  cus
on cus.子客户主键 = cu.pk_cubasdoc
where (1=1)  
and length(ib.invcode) > 4 
and ii.dr = 0 
and ii.dbilldate >= to_char (sysdate-181,'yyyy-mm-dd') 
 )ma  group by  主客户主键) fp
 on cu.主客户主键 = fp.主客户主键










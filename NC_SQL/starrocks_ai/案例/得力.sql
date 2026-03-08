
select ma.存货名称,ma.存货编码,ma.品类,ma.品牌,ma.装箱量,sum(北京三十天销量) 北京三十天销量,sum(北京九十天销量) 北京九十天销量
,sum(成都三十天销量) 成都三十天销量,sum(成都九十天销量) 成都九十天销量
,sum(哈尔滨三十天销量) 哈尔滨三十天销量,sum(哈尔滨九十天销量) 哈尔滨九十天销量
,sum(南京三十天销量) 南京三十天销量,sum(南京九十天销量) 南京九十天销量
,sum(沈阳三十天销量) 沈阳三十天销量,sum(沈阳九十天销量) 沈阳九十天销量
,sum(西安三十天销量) 西安三十天销量,sum(西安九十天销量) 西安九十天销量,
f.九十天数量,f.三十天数量
 from(
select ma.存货名称,ma.存货编码,ma.品类,ma.品牌,ma.装箱量,
case when 客户分仓='北京'then sum(三十天数量) else 0 end 北京三十天销量,
  case when 客户分仓='北京'then sum(九十天数量) else 0 end 北京九十天销量,
case when 客户分仓='成都'then sum(三十天数量) else 0 end 成都三十天销量,
  case when 客户分仓='成都'then sum(九十天数量) else 0 end 成都九十天销量,
    case when 客户分仓='哈尔滨'then sum(三十天数量) else 0 end 哈尔滨三十天销量,
  case when 客户分仓='哈尔滨'then sum(九十天数量) else 0 end 哈尔滨九十天销量,
    case when 客户分仓='南京'then sum(三十天数量) else 0 end 南京三十天销量,
  case when 客户分仓='南京'then sum(九十天数量) else 0 end 南京九十天销量,
    case when 客户分仓='沈阳'then sum(三十天数量) else 0 end 沈阳三十天销量,
  case when 客户分仓='沈阳'then sum(九十天数量) else 0 end 沈阳九十天销量,
    case when 客户分仓='西安'then sum(三十天数量) else 0 end 西安三十天销量,
  case when 客户分仓='西安'then sum(九十天数量) else 0 end 西安九十天销量,
sum(九十天数量) 九十天数量,
sum(三十天数量) 三十天数量
from (
select ma.客户名称, ma.存货名称,ma.存货编码,ma.品类 ,ma.品牌,ma.客户编码,ma.装箱量,
case when ma.客户编码 in ('913920647042',
'913833184375',
'913256656786',
'913314876754',
'918634337665',
'918737185128',
'917310470079') then '北京'
when  ma.客户编码 in ('918280005530',
'918725740782',
'918314132414') then '成都' 
when  ma.客户编码 in ('915945054188') 
 then '哈尔滨'
when  ma.客户编码 in ('913805768172',
'915337224960',
'915850583615',
'918123501134',
'915084883453',
'0574-27899266',
'918620162356',
'913485696434',
'915396104610',
'915000340653',
'913687719721',
'917379132217') then '南京'
when  ma.客户编码 in ('913804975217',
'913604400141') 
 then '沈阳'
when  ma.客户编码 in ('917693474446',
'917792271008',
'918099223910',
'913895008179') 
 then '西安'
   else '异常'end 客户分仓,
sum(case when ma.日期 >= to_char(sysdate - 31,'yyyy-mm-dd') then ma.数量 else 0  end ) as 三十天数量,
sum(case when ma.日期 >= to_char(sysdate - 91,'yyyy-mm-dd') then  ma.数量 else 0  end ) as 九十天数量
 from  (
select ma.客户编码,ma.客户名称,ma.存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,(ma.价税合计/ma.数量)as 单价,ma.是否赠品,ma.业务类型,ma.业务属性,ma.本币价税合计,ma.批发价税合计,ma.价税合计,ma.流水,ma.毛利,ma.成本,ma.市场部,ma.部门,ma.业务员,ma.日期,ma.省,ma.市
, substr(ma.日期,1,7) 月,ma.库房,ma.装箱量
from(
select ma.客户编码,ma.装箱量,ma.客户名称,ma.存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,ma.是否赠品,ma.业务类型,ma.业务属性,ma.本币价税合计,ma.批发价税合计,ma.价税合计,ma.流水,ma.毛利,ma.成本,ma.市场部,ma.部门,ma.业务员,ma.日期,ma.省,ma.市,ma.库房
from (select 
cu.custcode as 客户编码,
cu.custname as 客户名称,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
cg.def2 as 装箱量,
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
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,ch.def2
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
  where ma.日期 >= to_char(sysdate -91,'yyyy-mm-dd')
  and  ma.大类   in ('兼容')
 and ma.客户编码 in ('913805768172',
'918280005530',
'913804975217',
'917693474446',
'913920647042',
'917792271008',
'915337224960',
'915850583615',
'913833184375',
'918123501134',
'915084883453',
'0574-27899266',
'918099223910',
'918725740782',
'918620162356',
'913485696434',
'913256656786',
'915396104610',
'918314132414',
'913604400141',
'913314876754',
'913895008179',
'918634337665',
'915000340653',
'918737185128',
'917310470079',
'913687719721',
'917379132217',
'915945054188' )
 ) ma  group by ma.客户名称,ma.存货名称,ma.存货编码,ma.品类,ma.品牌,ma.客户编码,ma.装箱量 ) ma
 
 group by ma.存货名称,ma.存货编码,ma.品类,ma.品牌,ma.客户分仓,ma.装箱量 ) ma 
  left join (
  select ma.存货编码,
 sum(ma.三十天数量)三十天数量 ,
 sum(ma.九十天数量)九十天数量
from(
select ma.存货编码,sum(case when ma.日期 >= to_char(sysdate - 31,'yyyy-mm-dd') then ma.数量 else 0  end ) as 三十天数量,
sum(case when ma.日期 >= to_char(sysdate - 91,'yyyy-mm-dd') then  ma.数量 else 0  end ) as 九十天数量
from (select 
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
LEFT join (
select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc
         )cg
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
  )ma where ma.日期 >= to_char(sysdate -91,'yyyy-mm-dd') group by ma.存货编码 )ma  group by ma.存货编码 )  f
  on f.存货编码=ma.存货编码
 
  group by ma.存货名称,ma.存货编码,ma.品类,ma.品牌,f.九十天数量,
f.三十天数量,ma.装箱量 order by  ma.存货编码  desc


select  a.客户编码,a.客户名称,a.业务员,nvl(a.存货编码,b.存货编码)存货编码,nvl(a.存货名称,b.存货名称)存货名称,nvl(a.大类,b.大类)大类,nvl(a.品类,b.品类)品类,nvl(a.品牌,b.品牌)品牌,nvl(a.小类,b.小类)小类,a.数量,a.订单量,a.近三十天销量,a.近三十天单量,b.SOP现存量,b.FBP现存量,b.总库存 from 
(select ma.客户编码,ma.客户名称,ma.业务员,ma.存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,sum(ma.数量) as 数量,count(distinct ma.订单号 ) 订单量 ,sum(近三十天销量)as 近三十天销量,count(distinct ma.近三十天订单 )近三十天单量
from (
select 
zjs.vreceiptcode 订单号,
case when   (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) >= to_char(sysdate-31,'yyyy-mm-dd') then zjs.vreceiptcode  else null end 近三十天订单,
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
case when   (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) >= to_char(sysdate-31,'yyyy-mm-dd') then js.nnewbalancenum else 0 end 近三十天销量,
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
join nc5x.so_square zjs on zjs.csaleid  = js.csaleid
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
left join nc5x.so_sale  hs
 on js.csourcebillid   =hs.csaleid 
where 
  length(cg.invcode) <> 4
  and js.dr=0
  and '流水' <> 'null'
  and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) >= to_char(sysdate-61,'yyyy-mm-dd')
  ) ma 
  where  ma.市场部 in ('直营+微分销')
  and ma.客户编码 in ('1101b180','1101b179')
   group by ma.客户编码,ma.客户名称,ma.业务员,ma.存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类  order by ma.客户名称,ma.存货编码) a 
 full join 
 (select
bb.invname 存货名称 ,
bb.invcode 存货编码,
bb.width as 大类,
bb.length as 品类,
bb.invpinpai as 品牌,
bb.height as 小类,
sum(case when dd.storcode in ('067','078','068','072')  then dd.nonhandnum else 0 end  ) SOP现存量,
sum(case when dd.storcode in ('073','079','070','074','080')  then dd.nonhandnum else 0 end  ) FBP现存量,
SUM(dd.nonhandnum) 总库存 
from nc5x.bd_invbasdoc bb
left join (select aa.cinvbasid , aa.cwarehouseid, aa.nonhandnum,cc.pk_stordoc,cc.storname,cc.storcode
      from nc5x.ic_onhandnum aa
      join nc5x.bd_stordoc cc
      on aa.cwarehouseid = cc.pk_stordoc ) dd
on dd.cinvbasid = bb.pk_invbasdoc
where dd.nonhandnum<>0 and dd.storcode  in ('080','067','078','068','072','073','079','070','074')
GROUP BY bb.invname,bb.invcode, bb.width,bb.length ,bb.invpinpai ,bb.height )  b on a.存货编码 = b.存货编码

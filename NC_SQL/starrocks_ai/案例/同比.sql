select nvl(a.大类,b.大类)||nvl(a.部门, b.部门)||nvl( a.市场部, b.市场部)|| nvl(a.业务员,b.业务员)||nvl(a.客户名称,b.客户名称)||nvl(a.类型,b.类型)||nvl(a.日期,b.日期) rk,nvl(a.大类,b.大类)大类,nvl(a.部门, b.部门) 部门,nvl( a.市场部, b.市场部)市场部 ,nvl(a.业务员,b.业务员)业务员,nvl(a.日期,b.日期)日期,nvl(a.客户名称,b.客户名称) 客户名称 ,nvl(a.类型,b.类型)类型 ,结算数量,出货数量,结算流水,出货流水 from (
select 
ma.大类,业务员,部门,市场部,日期,年份,类型,客户名称,
sum(数量) 结算数量,
sum(流水) 结算流水
from  
( 
select 
ib.width as 大类,
substr(ii.dbilldate,6,5) as 日期,
substr(ii.dbilldate,1,4) as 年份,
case when ii.dbilldate  between  to_char(trunc(add_months(sysdate,-12),'yy'),'yyyy-mm-dd') and to_char(trunc(sysdate,'yy')-1,'yyyy-mm-dd')  then '去年'
  else '今年'end 类型,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
case when cu.custname is null then '北京扬帆耐力贸易有限公司' else cu.custname  end as 客户名称,
ib.nnumber as 数量,
ib.noriginalcurmny as 流水
  from nc5x.so_saleinvoice ii
  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode, ib.noriginalcurmny
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
    on ib.csaleid = ii.csaleid
  left join nc5x.v_zlw_cust cu 
    on ii.creceiptcorpid = cu.pk_cumandoc
    LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
     left join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
     left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
left join nc5x.bd_psndoc  us
on us.pk_psndoc= ii.cemployeeid
where  length(ib.invcode) > 4 
and  ii.dr=0  
and ib.width  in ('兼容','原装','打印机')
-- and (cu.deptname in ('北京市场部','外阜市场部','渠道部','区域销售部','平台业务部','SI业务部') or (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) in( '刘喜丹','共享客户'))     
and ((ii.dbilldate between  to_char(trunc(add_months(sysdate,-12),'yy'),'yyyy-mm-dd') and to_char(add_months(sysdate-1,-12),'yyyy-mm-dd') )or 
(ii.dbilldate between to_char(trunc(sysdate,'yy'),'yyyy-mm-dd') and to_char(sysdate-1,'yyyy-mm-dd')))
 )ma where ma.客户名称 <> '京东-智通仁和（POP一盘货）' group by ma.大类,业务员,部门,市场部,日期,年份,类型,客户名称) a 
 full join 
(select 
 ma.大类,业务员,部门,市场部,日期,年份,类型,客户名称,
sum(数量) 出货数量,sum(流水) 出货流水
from (
select 
substr((case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ),6,5) 日期,
substr((case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ),1,4) 年份,
case when (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) between  to_char(trunc(add_months(sysdate,-12),'yy'),'yyyy-mm-dd') and to_char(trunc(sysdate,'yy')-1,'yyyy-mm-dd')  then '去年'
  else '今年'end 类型,
cg.width as 大类,
js.nnewbalancenum as 数量,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
case when cu.custname is null then '北京扬帆耐力贸易有限公司' else cu.custname  end as 客户名称
from nc5x.so_squaredetail js
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,cg.pk_invbasdoc
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
and cg.width in ('兼容','原装','打印机')
-- and (cu.deptname in ('北京市场部','外阜市场部','渠道部','区域销售部','平台业务部','SI业务部') or (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) in( '刘喜丹','共享客户') )    
 and (((case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) between  to_char(trunc(add_months(sysdate,-12),'yy'),'yyyy-mm-dd') and to_char(add_months(sysdate-1,-12),'yyyy-mm-dd') )or 
((case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) between to_char(trunc(sysdate,'yy'),'yyyy-mm-dd') and to_char(sysdate-1,'yyyy-mm-dd')))
  ) ma where ma.客户名称 <> '京东-智通仁和（POP一盘货）' group by ma.大类,业务员,部门,市场部,日期,年份,类型,客户名称) b on a.大类=b.大类 and a.业务员 = b.业务员 and a.日期= b.日期 and a.年份= b.年份 and a.客户名称 = b.客户名称 and a.部门 = b.部门 and a.市场部= b.市场部
  


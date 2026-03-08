
select 省 as PROVINCE,ts as THE_MONTH,大类 as THE_CLASS,业务员 as SalesName,
sum(SalesVolumeThisYear) as SalesVolumeThisYear,
sum(SalesVolumeOldYear) as SalesVolumeOldYear,
sum(ProfitThisYear) as ProfitThisYear,
sum(ProfitOldYear) as ProfitOldYear
from (
select 年份,月份,省,大类,业务员,sum(流水) 流水 ,sum(毛利)毛利 ,substr( 月份, 6, 2 ) AS ts,
case when 年份 = to_char(sysdate,'yyyy') then sum(流水) else 0 end SalesVolumeThisYear,
case when 年份 = to_char(TRUNC(ADD_MONTHS(TRUNC(SYSDATE, 'YEAR'), -12) , 'YEAR'),'yyyy') then sum(流水) else 0 end SalesVolumeOldYear,
case when 年份 = to_char(sysdate,'yyyy') then sum(毛利) else 0 end ProfitThisYear,
case when 年份 = to_char(TRUNC(ADD_MONTHS(TRUNC(SYSDATE, 'YEAR'), -12) , 'YEAR'),'yyyy') then sum(毛利) else 0 end ProfitOldYear
 from  (
select
cg.width as 大类,
js.nnewbalancenum as 数量,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end-js.ncostmny AS 毛利,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期,
substr((case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ),1,7) 月份,
substr((case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ),1,4) 年份,
cu.sf as 省,
cu.cs as 市
from nc5x.so_squaredetail js
left join  nc5x.so_square zjs on js.csaleid = zjs.csaleid 
LEFT join (
select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,ch.unitweight,ch.unitvolume,
cg.refsaleprice as 批发售价
,cg.def5 as 代理价 
,cg.lowestprice   as 最低限价
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
left join nc5x.so_sale hl
on js.csourcebillid = hl.csaleid
left join nc5x.sm_user  su1 
on hl.coperatorid = su1.cuserid
left join nc5x.bd_stordoc dd
on js.cwarehouseid = dd.pk_stordoc
where 
length(cg.invcode) >= 5
and js.dr=0
and ((
js.dapprovedate BETWEEN to_char ( trunc ( sysdate, 'yyyy' ), 'yyyy-mm-dd' ) AND to_char (  sysdate , 'yyyy-mm-dd' ) or
js.dmakedate BETWEEN to_char ( trunc ( sysdate, 'yyyy' ), 'yyyy-mm-dd' ) AND to_char (  sysdate , 'yyyy-mm-dd' ) )
or 
(
js.dapprovedate BETWEEN to_char ( TRUNC(ADD_MONTHS(TRUNC(SYSDATE, 'YEAR'), -12) , 'YEAR') , 'yyyy-mm-dd' )  AND  to_char ( TRUNC(SYSDATE) - INTERVAL '1' YEAR, 'yyyy-mm-dd' ) or
js.dmakedate BETWEEN to_char ( TRUNC(ADD_MONTHS(TRUNC(SYSDATE, 'YEAR'), -12) , 'YEAR') , 'yyyy-mm-dd' )  AND  to_char ( TRUNC(SYSDATE) - INTERVAL '1' YEAR, 'yyyy-mm-dd' )
 )
)
) ma where ( (日期 BETWEEN to_char ( trunc ( sysdate, 'yyyy' ), 'yyyy-mm-dd' )  AND  to_char (  sysdate , 'yyyy-mm-dd' )) or 
(日期 BETWEEN to_char ( TRUNC(ADD_MONTHS(TRUNC(SYSDATE, 'YEAR'), -12) , 'YEAR') , 'yyyy-mm-dd' )  AND   to_char ( TRUNC(SYSDATE) - INTERVAL '1' YEAR, 'yyyy-mm-dd' ) )
)
group by 
年份,月份,省,大类,业务员 ) 
group by
省,大类,业务员,ts





SELECT
SALEDEPT,
DEPT,
SALEMAN,
CUSNAME,
XY.流水月份,
custcode,
XY.是否子账户,
max(xy.dmakedate) 流水最晚日期,
min(xy.dmakedate) 流水最早日期,
max(xy.CREATETIME) 客户最晚日期,
min(xy.CREATETIME) 客户最早日期,
COUNT(DISTINCT CUSNAME) 客户数,
SUM(TURNOVER),
sum(case  when  CATEGORY1='兼容' then TURNOVER else 0 end ) 兼容流水,
sum(case  when  CATEGORY1 ='原装' then TURNOVER else 0 end ) 原装流水,
sum(case  when  CATEGORY1 ='打印机' then TURNOVER else 0 end ) 打印机流水
FROM(
select 
cg.width as CATEGORY1,
cu.deptname as SALEDEPT,
cu.n_deptname as DEPT,
cu.psnname as SALEMAN,
cu.custname as CUSNAME,
cu.custcode,
CB.CREATETIME,
translate( cu.custcode,'#'||translate(cu.custcode ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ','#') ,'/') as 是否子账户,
js.dmakedate,
yw.busicode,
to_char(to_date(js.dmakedate,'yyyy-mm-dd'),'yyyy-mm') as 流水月份,
substr(CB.CREATETIME,1,7) as 客户月份,
ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2) AS TURNOVER
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
LEFT join nc5x.BD_CUBASDOC CB
on cu.CUSTCODE = CB.CUSTCODE
where 
CB.CREATETIME >= to_char(trunc(sysdate,'YYYY'),'yyyy-mm-dd')
and length( cg.invcode) >4
  and cg.width IN ('兼容','原装','打印机')
  and js.dr=0
 and  cu.custname not  in (
 select distinct cu.custname from nc5x.so_squaredetail js LEFT join nc5x.v_zlw_cust cu on js.ccustomerid = cu.pk_cumandoc 
 LEFT join nc5x.BD_CUBASDOC CB
on cu.CUSTCODE = CB.CUSTCODE where CB.CREATETIME >= to_char(trunc(sysdate,'YYYY'),'yyyy-mm-dd') and js.dmakedate < to_char(trunc(sysdate,'YYYY'),'yyyy-mm-dd')
 )  
 
) XY  where length(XY.是否子账户) < 2 or XY.是否子账户 is null 
GROUP BY 
XY.SALEDEPT
,XY.DEPT
,XY.SALEMAN
,XY.流水月份
,custcode
,XY.是否子账户
,xy.CUSNAME









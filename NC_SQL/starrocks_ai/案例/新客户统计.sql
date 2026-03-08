SELECT
SALEDEPT,
DEPT,
SALEMAN,
XY.流水月份,
XY.客户月份,
CUSNAME 客户名称,
COUNT(DISTINCT(case  when  CATEGORY1 ='兼容'and xy.busicode='s005' then CUSNAME else  null  end ) ) as 放货客户数 ,
SUM(TURNOVER),
sum(case  when  CATEGORY1='兼容' then TURNOVER else 0 end ) 兼容流水,
sum(case  when  CATEGORY1 ='原装' then TURNOVER else 0 end ) 原装流水,
sum(case  when  CATEGORY1 ='打印机' then TURNOVER else 0 end ) 打印机流水,
sum(case  when  CATEGORY1 ='兼容'and xy.busicode='s005' then TURNOVER else 0 end ) 兼容放货流水
FROM(
select 
cg.width as CATEGORY1,
cu.deptname as SALEDEPT,
cu.n_deptname as DEPT,
cu.psnname as SALEMAN,
cu.custname as CUSNAME,
js.dmakedate ,
yw.busicode ,
to_char(to_date(js.dmakedate,'yyyy-mm-dd'),'yyyy-mm') as 流水月份 ,
substr(CB.CREATETIME,1,7) as 客户月份 ,
ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2) AS TURNOVER
from nc5x.v_zlw_cust cu 
LEFT join nc5x.so_squaredetail js
on js.ccustomerid = cu.pk_cumandoc 
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
        from nc5x.bd_invmandoc cg 
        join nc5x.bd_invbasdoc ch 
        on cg.pk_invbasdoc = ch.pk_invbasdoc)cg
on js.cinventoryid = cg.pk_invmandoc
LEFT join nc5x.bd_busitype yw 
on js.cbiztype = yw.pk_busitype 
LEFT join nc5x.BD_CUBASDOC CB 
on cu.CUSTCODE = CB.CUSTCODE 
where  
  cg.invcode <>  '9805' 
  and cg.invcode <>  '9810' 
  and cg.invcode <>  '9807' 
  and cg.invcode <>  '9809' 
  and cg.invcode <>  '9899' 
   and cg.invcode <>  '9898' 
  and cg.width IN ('兼容','原装','打印机') 
  and js.dr=0 
  and ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum * js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2) > 0
) XY where 
  XY.流水月份='2021-03' and  XY.客户月份='2021-03'
GROUP BY XY.SALEDEPT,XY.DEPT,XY.SALEMAN,XY.流水月份,XY.客户月份,xy.CUSNAME


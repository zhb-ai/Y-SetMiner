 select * from 
 (SELECT
SALEDEPT,
DEPT,
SALEMAN,
XY.流水月份,
max(xy.dmakedate) 流水最晚日期,
min(xy.dmakedate) 流水最早日期,
max(xy.CREATETIME) 客户最晚日期,
min(xy.CREATETIME) 客户最早日期,
COUNT(DISTINCT CUSNAME) 客户数,
--COUNT(DISTINCT(case  when  CATEGORY1 ='兼容'and xy.busicode='s005' then CUSNAME else  null  end ) ) as 放货客户数 ,
SUM(TURNOVER),
sum(case  when  CATEGORY1='兼容' then TURNOVER else 0 end ) 兼容流水,
sum(case  when  CATEGORY1 ='原装' then TURNOVER else 0 end ) 原装流水,
sum(case  when  CATEGORY1 ='打印机' then TURNOVER else 0 end ) 打印机流水
--sum(case  when  CATEGORY1 ='兼容'and xy.busicode='s005' then TURNOVER else 0 end ) 兼容放货流水
FROM(
select 
cg.width as CATEGORY1,
cu.deptname as SALEDEPT,
cu.n_deptname as DEPT,
cu.psnname as SALEMAN,
cu.custname as CUSNAME,
CB.CREATETIME,
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
js.dmakedate >= TO_CHAR(sysdate-90,'YYYY-MM-DD')
 and js.dmakedate <= TO_CHAR(sysdate ,'YYYY-MM-DD')
and CB.CREATETIME >= TO_CHAR(sysdate-90,'YYYY-MM-DD')
and CB.CREATETIME <= TO_CHAR(sysdate ,'YYYY-MM-DD')   and
--js.dmakedate >= TO_CHAR(sysdate-450,'YYYY-MM-DD')
 --and js.dmakedate <= TO_CHAR(sysdate-360 ,'YYYY-MM-DD')
--and CB.CREATETIME >= TO_CHAR(sysdate-450,'YYYY-MM-DD')
--and CB.CREATETIME <= TO_CHAR(sysdate-360 ,'YYYY-MM-DD')   and
 length(cg.invcode)>4
and cg.width IN ('兼容','原装','打印机')
and js.dr=0
and ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum * js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2) > 0
--and cu.custname ='张家口领先未来办公服务有限公司'
) XY --where   XY.流水月份='2021-02'and XY.客户月份='2021-02'
GROUP BY 
XY.SALEDEPT
,XY.DEPT 
,XY.SALEMAN
,XY.流水月份 )a
 left join  
(
SELECT
SALEDEPT,
DEPT,
TRADER,
流水月份,
COUNT(DISTINCT CUSNAME) as 放货客户数, 
SUM(TURNOVER) 兼容放货流水
FROM
(
select 
ib.width as CATEGORY,
cu.deptname as SALEDEPT,
cu.n_deptname as DEPT,
cu.psnname as TRADER,
to_char(to_date(ii.dbilldate,'yyyy-mm-dd'),'yyyy-mm') as 流水月份,
cu.custname as CUSNAME,
ib.nmny AS TURNOVER
from nc5x.so_saleinvoice ii
left join (select ib.csaleid,ib.nnumber,ib.nmny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
          on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu
on ii.creceiptcustomerid = cu.pk_cumandoc
LEFT join nc5x.bd_busitype yw
on ii.cbiztype  = yw.pk_busitype
LEFT join nc5x.BD_CUBASDOC CB
on cu.CUSTCODE = CB.CUSTCODE
left join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
where 
ii.dbilldate >= TO_CHAR(sysdate-90,'YYYY-MM-DD')
and ii.dbilldate <= TO_CHAR(sysdate,'YYYY-MM-DD')
and CB.CREATETIME >= TO_CHAR(sysdate-90,'YYYY-MM-DD')
and CB.CREATETIME <= TO_CHAR(sysdate ,'YYYY-MM-DD')  
  and length(ib.invcode)> 4
  and ib.width IN ('兼容')
  and ii.dr= 0
  and yw.busicode = 's005'
  AND ck.storname  not in ('首创虚拟库') 
  and ib.nmny > 0
) XY
GROUP BY XY.SALEDEPT,XY.DEPT,XY.TRADER,xy.流水月份 ) m on a.流水月份= m.流水月份 and a.saleman=m.TRADER







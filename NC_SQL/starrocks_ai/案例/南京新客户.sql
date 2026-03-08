SELECT
SALEDEPT,
DEPT,
SALEMAN,
CUSNAME, 
SUM(TURNOVER)

FROM
(
select 
cg.width as CATEGORY,
cu.deptname as SALEDEPT,
cu.n_deptname as DEPT,
cu.psnname as SALEMAN,
cu.custname as CUSNAME,
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
where js.dmakedate >= TO_CHAR(trunc(sysdate,'mm'),'YYYY-MM-DD')
  and js.dmakedate <= TO_CHAR(last_day(sysdate) ,'YYYY-MM-DD')
 and CB.CREATETIME >= TO_CHAR(trunc(sysdate,'mm'),'YYYY-MM-DD')
 and CB.CREATETIME <= TO_CHAR(last_day(sysdate) ,'YYYY-MM-DD')
  and cg.invcode <> '9805'
  and cg.invcode <> '9810'
  and cg.invcode <> '9807'
  and cg.invcode <> '9809'
  and cg.invcode <> '9899'
  and cg.width IN ('兼容','原装','打印机')
  and js.dr=0
  --and yw.busicode <> 's005'
  and '流水' <> 'null' and cu.n_deptname like'%南京%'
  and ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2) > 0
) XY
GROUP BY XY.SALEDEPT,XY.DEPT,CUSNAME, XY.SALEMAN ORDER BY 4 asc

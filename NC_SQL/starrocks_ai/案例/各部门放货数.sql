SELECT
SALEDEPT,
DEPT,
TRADER,
CUSNAME,
COUNT(DISTINCT CUSNAME), 
SUM(TURNOVER)

FROM
(
select 
ib.width as CATEGORY1,
cu.deptname as SALEDEPT,
cu.n_deptname as DEPT,
cu.psnname as TRADER,
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

where ii.dbilldate BETWEEN  TO_CHAR(trunc(sysdate,'mm'),'YYYY-MM-DD')
   AND TO_CHAR(last_day(sysdate) ,'YYYY-MM-DD')
  and ib.invcode <> '9805'
  and ib.invcode <> '9810'
  and ib.invcode <> '9807'
  and ib.invcode <> '9809'
  and ib.invcode <> '9899'
  and ib.width IN ('兼容','原装','打印机')
  and ii.dr=0
  and yw.busicode = 's005'
  and '流水' <> 'null'
  )GROUP BY SALEDEPT,
DEPT,CUSNAME,
TRADER
  --and ib.nmny > 0 and cu.psnname like '%南京%'

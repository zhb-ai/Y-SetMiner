select 
substr(ma.日期,0,7) as 月度,
ma.专管部门,
ma.width as 大类,
ma.length as 品类,
ma.invpinpai as 品牌,
SUM(case  nvl2( TRIM(REGEXP_replace(ma.VBODYDEF8,'[0-9|+|-|.]','')),0,1)  when 1 then to_number(ma.VBODYDEF8) else 0 end ) AS 服务费,
ROUND(SUM((CASE WHEN TO_NUMBER(ma.nnewbalancenum*ma.vbodydef5)=0 OR ma.nnewbalancenum*ma.vbodydef5 IS NULL THEN ma.nsummny ELSE ma.nnewbalancenum*ma.vbodydef5 END)/(ma.NTAXRATE*0.01+1)),2)   AS 流水,
ROUND(SUM((CASE WHEN TO_NUMBER(ma.nnewbalancenum*ma.vbodydef5)=0 OR ma.nnewbalancenum*ma.vbodydef5 IS NULL THEN ma.nsummny ELSE ma.nnewbalancenum*ma.vbodydef5 END)/(ma.NTAXRATE*0.01+1)),2)-SUM(ma.ncostmny) AS 毛利
--case when ma.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(ma.nnewbalancenum*ma.vbodydef5)=0 OR ma.nnewbalancenum*ma.vbodydef5 IS NULL THEN ma.nsummny ELSE ma.nnewbalancenum*ma.vbodydef5 END)/(ma.NTAXRATE*0.01+1),2)) end   AS 流水,
--case when ma.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(ma.nnewbalancenum*ma.vbodydef5)=0 OR ma.nnewbalancenum*ma.vbodydef5 IS NULL THEN ma.nsummny ELSE ma.nnewbalancenum*ma.vbodydef5 END)/(ma.NTAXRATE*0.01+1),2)) end-ma.ncostmny AS 毛利
       from 
(
select 
(CASE WHEN cu.n_deptname='渠道部' or cu.psnname='南京雄狮-蒋继欣' THEN cu.psnname ELSE cu.n_deptname END) AS 专管部门,
cg.width ,
cg.length ,
cg.invpinpai,
js.VBODYDEF8,
js.nnewbalancenum,
js.vbodydef5,
js.nsummny,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) as 日期,
js.NTAXRATE,
js.ncostmny,
js.blargessflag
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
where (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) >=  '2018-01-01'
  and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) <=  '2020-04-16'
  and cg.invcode <> '9805'
  and cg.invcode <> '9810'
  and cg.invcode <> '9807'
  and cg.invcode <> '9809'
  and cg.invcode <> '9899'
  and cg.invcode <> '9898'
  and cg.width in ('兼容','原装','打印机')
  and js.dr=0
  and yw.busicode <> 's005'
  and '流水' <> 'null'
union all
select 
(CASE WHEN cu.n_deptname='渠道部' or cu.psnname='南京雄狮-蒋继欣' THEN cu.psnname ELSE cu.n_deptname END) AS 专管部门,
cg.width ,
cg.length ,
cg.invpinpai ,
js.VBODYDEF8,
js.nnewbalancenum,
js.vbodydef5,
js.nsummny,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) as 日期 ,
js.NTAXRATE,
js.ncostmny,
js.blargessflag
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
where (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) >= '2020-04-17'
  and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) <= '2020-12-31'
  and cg.invcode <> '9805'
  and cg.invcode <> '9810'
  and cg.invcode <> '9807'
  and cg.invcode <> '9809'
  and cg.invcode <> '9899'
  and cg.invcode <> '9898'
  and cg.width in ('兼容','原装','打印机')
  and js.dr=0
  --and yw.busicode <> 's005'
  and '流水' <> 'null') ma
  GROUP BY substr(ma.日期,0,7),ma.专管部门,ma.width,ma.length,ma.invpinpai ORDER BY 1,2

select 
invcode,
sum(case when storname =  '北京仓' then nshouldinnum else 0 end)   北京在途,
sum(case when storname in ('沈阳仓','沈 阳数码','沈 阳维用') then nshouldinnum else 0 end)   沈阳在途, 
sum(case when storname in ('重庆仓','重庆泰兴') then nshouldinnum else 0 end)   重庆在途, 
sum(case when storname in  ('哈尔滨仓','哈尔滨教化','哈尔滨船舶')  then nshouldinnum else 0 end)   哈尔滨在途, 
sum(case when storname in  ('西安仓','西安科贸') then nshouldinnum else 0 end)   西安在途, 
sum(case when storname in  ('南京仓') then nshouldinnum else 0 end)   南京在途, 
sum(case when storname in ('成都仓') then nshouldinnum else 0 end)   成都在途
FROM
(select ck.storname,c.cinvbasid,iv.invcode,c.nshouldinnum,c.TMAKETIME,iv.invname from (
select h.CGENERALHID,h.CWAREHOUSEID,b.cinvbasid,b.nshouldinnum,h.TMAKETIME from nc5x.ic_general_h  h 
join nc5x.ic_general_b b  on  h.CGENERALHID=b.CGENERALHID 
where h.CBILLTYPECODE ='4E' AND h.DACCOUNTDATE IS NULL  and h.dr=0 and b.dr=0 
) c LEFT join nc5x.bd_stordoc ck on c.cwarehouseid = ck.pk_stordoc
 LEFT join nc5x.bd_invbasdoc iv on c.cinvbasid= iv.pk_invbasdoc ) 
WHERE storname in ('北京仓','沈阳仓','沈 阳数码','沈 阳维用','重庆仓','重庆泰兴','哈尔滨仓','哈尔滨教化','哈尔滨船舶','西安仓','西安科贸','南 京雄狮','南京仓','中山仓','成都仓','成 都门市')
GROUP BY invcode,cinvbasid 
order by 1 asc

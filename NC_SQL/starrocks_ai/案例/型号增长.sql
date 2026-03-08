select a.*,
case
when 第一季销量 >100 and  增长率>=1 then '翻倍增长'
when 第一季销量 >100  and  增长率>=0.5 then '迅速增长'
when 增长率 >= 0.2 then '增长'
when 增长率 >= -0.1 then '正常'
when 总销量 >400  and  增长率 >= -0.5 then '下降'
when 总销量 >400  and 增长率 >= -1 then '迅速下降'
else '' end 增长判断
from (
select  存货主键,
存货编码, 存货名称,大类,品牌,品类,小类,
sum(第一季销量)第一季销量,
sum(第二季销量)第二季销量,
sum(第三季销量)第三季销量,
sum(第四季销量)第四季销量,
sum(数量) 总销量,
case 
when sum(第一季销量)<= 0 and sum(第四季销量)>=100 then 1
when sum(第四季销量)<= 0 and sum(第一季销量)>=0 then -1
when sum(第一季销量)>=100 or sum(第四季销量)>= 100 then sum(第四季销量)/sum(第一季销量)-1 else 0 end 增长率,
case when sum(第四季销量)>= 100 then sum(第四季销量)/sum(数量) else 0 end 近期销量占比,
case  when sum(第一季销量)+sum(第二季销量) <= 0 and sum(第三季销量)+sum(第四季销量)> 200 then 1
when sum(第一季销量)+sum(第二季销量) >= 200 or sum(第三季销量)+sum(第四季销量) > 200 then   (sum(第三季销量)+sum(第四季销量))/  (sum(第一季销量)+sum(第二季销量)) -1 else 0 end  半年增长率
from  
( select 
ib.pk_invbasdoc 存货主键,
ii.dbilldate as 日期,
case when  ii.dbilldate between to_char(sysdate-360,'yyyy-mm-dd') and to_char(sysdate-271,'yyyy-mm-dd') then ib.nnumber else 0 end 第一季销量,
case when  ii.dbilldate between to_char(sysdate-270,'yyyy-mm-dd') and to_char(sysdate-181,'yyyy-mm-dd') then  ib.nnumber else 0 end 第二季销量,
case when  ii.dbilldate between to_char(sysdate-180,'yyyy-mm-dd') and to_char(sysdate-91,'yyyy-mm-dd') then   ib.nnumber else 0 end 第三季销量,
case when  ii.dbilldate between to_char(sysdate-90,'yyyy-mm-dd') and to_char(sysdate,'yyyy-mm-dd') then  ib.nnumber else 0 end 第四季销量,
ib.nnumber as 数量,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌
from nc5x.so_saleinvoice ii
left  join (
select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode, ib.noriginalcurmny,
ch.unitvolume,
ch.unitweight
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc 
) ib
on ib.csaleid = ii.csaleid
where ii.dr = 0
and ib.width in ('兼容','原装') and ib.invpinpai not like '%网络版%'  and length(ib.invcode) > 4 
and ii.dbilldate >= to_char(sysdate-360,'yyyy-mm-dd')
) ma
group by 存货主键, 存货编码, 存货名称,大类,品牌,品类,小类 ) a  where 总销量 >200

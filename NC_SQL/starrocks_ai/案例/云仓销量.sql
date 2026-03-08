-- 云仓销量
select  
城市,存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,
sum(ma.数量) 总数量,sum(近三十天销量) 近三十天销量--  ,count(distinct ma.客户名称) as 客户数,count(ma.存货名称) as 单次
 from (
select
ii.dbilldate as 日期,
substr(ii.dbilldate,1,7) as 月份,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.psnname as 业务员,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
ib.nnumber as 数量,
case when ck.storcode in ('084','086') then '北京' when ck.storcode in ('087','092') then '南京' else '其他' end 城市,
case when ii.dbilldate between to_char(sysdate-31,'yyyy-mm-dd') and  to_char(sysdate-1,'yyyy-mm-dd') then ib.nnumber  else 0 end 近三十天销量,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌,
ck.storname as 库房,
ck.storcode as 库房编码
from nc5x.so_saleinvoice ii
join (
select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc
 ) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu 
on ii.creceiptcorpid = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_stordoc ck
on ii.cwarehouseid = ck.pk_stordoc
where (ii.dbilldate between to_char(sysdate-100,'yyyy-mm-dd') and to_char(sysdate-1,'yyyy-mm-dd'))   and not(ii.dbilldate between '2023-01-18' and '2023-01-27')
and ii.dr=0 
and ib.width  in ('原装','打印机')
--084  京东云仓北京一号库
--086  京东慧采-北京
--087  京东慧采-南京
--092  京东云仓南京库
and  ck.storcode in ('084','086','087','092')

 )ma 
  group by  城市, 存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 

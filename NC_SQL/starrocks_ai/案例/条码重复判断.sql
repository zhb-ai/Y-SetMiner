
select  d.条码,d.存货名称,d.数 from (
select  d.条码  ,d.存货名称,count(d.条码 ) 数 from (
select
aa.pk_invbasdoc as 主键,
aa.invcode     as 存货编码,
aa.invname     as 存货名称,
aa.def10 as 供应商,
aa.def2 as 装箱数,
bb.accflag as 是否辅币核算成本,
bb.costprice  as  参考成本,
aa.invtype     as 型号,
aa.invbarcode  as 条码,
aa.def19       as 税票型号,
aa.invpinpai   as 品牌,
aa.width    as 大类,
aa.length    as 品类,
aa.height   as 小类,
bb.refsaleprice    as 批发售价,
--bb.lowestprice   as 最低限价,
--bb.def2    as 零售指导价,
count(*) over(partition by aa.invcode  order by aa.invcode  asc ) rn ,
aa.def3    as ISBEIHUO,
bb.sealflag  as 是否封存
 from nc5x.bd_invbasdoc aa
join nc5x.bd_invmandoc bb
on aa.pk_invbasdoc = bb.pk_invbasdoc where aa.def10 is not null and aa.width ='兼容'and bb.sealflag   ='N'and aa.invbarcode is null ） d group by d.条码,d.存货名称）d where d.数  is null
--and d.条码 ='6941541600707'

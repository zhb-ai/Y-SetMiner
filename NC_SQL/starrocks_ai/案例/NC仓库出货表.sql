SELECT
  da.日期 AS the_date,
CASE
    
    WHEN da.市场部 IS NULL THEN
    '大客户部' ELSE da.市场部 
  END AS deptname,
  da.仓库 AS warehouse,
  da.收货省 AS province,
  da.大类 AS the_class,
  sum( da.总成本 ) AS turnover 
FROM
  (
  SELECT
    m.daudittime 订单审批时间,
    ii.daudittime 审批时间,
    ii.vreceiptcode,
    ii.creceiptcustomerid AS 主键,
    ib.pk_invbasdoc 存货主键,
    ii.VDEF9 运单号,
    ib.CORIGINALBILLCODE 订单号,
    m.vreceiptcode AS 外部单号,
    ii.VRECEIPTCODE 发票号,
    ii.dbilldate AS 日期,
    w.user_name AS 制单人,
    substr( ii.dbilldate, 1, 7 ) AS 月份,
    substr( ii.dbilldate, 1, 4 ) AS 年份,
    cu.deptname AS 市场部,
    cu.n_deptname AS 部门,(
    CASE
        
        WHEN cu.psnname IS NULL THEN
        us.psnname ELSE cu.psnname 
      END 
      ) AS 业务员,
      cu.pk_cubasdoc 客户主键,
      cu.custcode AS 客户编码,
      cu.custname AS 客户名称,
      cu.sf AS 省,
      cu.cs AS 市,
      II.VDEF7 AS 货运公司,
      ii.dr 删除标志,
      yw.businame AS 业务类型,
      ii.vnote AS 备注,
      ib.nnumber AS 数量,
      ib.nsummny AS 价税合计,
      ib.noriginalcurmny AS 流水,
      ib.nnumber * gp.nabprice AS 总成本,
      ib.unitvolume * ib.nnumber AS 体积,
      ib.unitweight * ib.nnumber AS 重量,
      ib.blargessflag AS 是否赠品,
      translate ( ib.invname, '#' || translate ( ib.invname, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', '#' ), '/' ) AS 型号,
      translate ( ib.invname, '#' || translate ( ib.invname, '0123456789', '#' ), '/' ) AS 型号1,
      ib.invcode AS 存货编码,
      ib.invname AS 存货名称,
      ib.length AS 品类,
      ib.width AS 大类,
      ib.height AS 小类,
      ib.invpinpai AS 品牌,
      dd.storname AS 库房,
      dd.storcode AS 仓库编码,
    CASE
        
        WHEN dd.storcode IN ( '001', '005', '013', '043', '084', '099', '065', '086', '070', '080', '067', '085' ) THEN
        '北京仓' 
        WHEN dd.storcode IN ( '022', '069', '02202', '073', '074', '078', '068', '087' ) THEN
        '南京仓' 
        WHEN dd.storcode IN ( '017', '019', '346', '01701' ) THEN
        '沈阳仓' 
        WHEN dd.storcode IN ( '051', '052' ) THEN
        '成都仓' 
        WHEN dd.storcode IN ( '056', '057' ) THEN
        '西安仓' 
        WHEN dd.storcode IN ( '020' ) THEN
        '哈尔滨仓' 
        WHEN dd.storcode IN ( '058' ) THEN
        '重庆仓' 
        WHEN dd.storcode IN ( '076', '145' ) THEN
        '中山仓' ELSE '其他' 
      END 仓库,
CASE
    
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%北京%' THEN
    '北京市' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%天津%' THEN
    '天津市' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%河北%' THEN
    '河北省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%山西%' THEN
    '山西省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%内蒙%' THEN
    '内蒙古自治区' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%辽宁%' THEN
    '辽宁省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%吉林%' THEN
    '吉林省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%黑龙江%' THEN
    '黑龙江省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%上海%' THEN
    '上海市' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%江苏%' THEN
    '江苏省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%浙江%' THEN
    '浙江省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%安徽%' THEN
    '安徽省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%福建%' THEN
    '福建省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%江西%' THEN
    '江西省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%山东%' THEN
    '山东省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%河南%' THEN
    '河南省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%湖北%' THEN
    '湖北省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%湖南%' THEN
    '湖南省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%广东%' THEN
    '广东省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%广西%' THEN
    '广西壮族自治区' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%海南%' THEN
    '海南省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%重庆%' THEN
    '重庆市' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%四川%' THEN
    '四川省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%贵州%' THEN
    '贵州省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%云南%' THEN
    '云南省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%西藏%' THEN
    '西藏自治区' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%陕西%' THEN
    '陕西省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%甘肃%' THEN
    '甘肃省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%青海%' THEN
    '青海省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%宁夏%' THEN
    '宁夏回族自治区' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%新疆%' THEN
    '新疆维吾尔自治区' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%台湾%' THEN
    '台湾省' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%香港%' THEN
    '香港特别行政区' 
    WHEN substr( m.vdef20, 0, 3 ) LIKE '%澳门%' THEN
    '澳门特别行政区' 
    WHEN cu.sf = '北京' THEN
    '北京市' 
    WHEN cu.sf = '天津' THEN
    '天津市' 
    WHEN cu.sf = '河北省' THEN
    '河北省' 
    WHEN cu.sf = '山西省' THEN
    '山西省' 
    WHEN cu.sf = '内蒙古自治区' THEN
    '内蒙古自治区' 
    WHEN cu.sf = '辽宁省' THEN
    '辽宁省' 
    WHEN cu.sf = '吉林省' THEN
    '吉林省' 
    WHEN cu.sf = '黑龙江省' THEN
    '黑龙江省' 
    WHEN cu.sf = '上海' THEN
    '上海市' 
    WHEN cu.sf = '江苏省' THEN
    '江苏省' 
    WHEN cu.sf = '浙江省' THEN
    '浙江省' 
    WHEN cu.sf = '安徽省' THEN
    '安徽省' 
    WHEN cu.sf = '福建省' THEN
    '福建省' 
    WHEN cu.sf = '江西省' THEN
    '江西省' 
    WHEN cu.sf = '山东省' THEN
    '山东省' 
    WHEN cu.sf = '河南省' THEN
    '河南省' 
    WHEN cu.sf = '湖北省' THEN
    '湖北省' 
    WHEN cu.sf = '湖南省' THEN
    '湖南省' 
    WHEN cu.sf = '广东省' THEN
    '广东省' 
    WHEN cu.sf = '广西壮族自治区' THEN
    '广西壮族自治区' 
    WHEN cu.sf = '海南省' THEN
    '海南省' 
    WHEN cu.sf = '重庆' THEN
    '重庆市' 
    WHEN cu.sf = '四川省' THEN
    '四川省' 
    WHEN cu.sf = '贵州省' THEN
    '贵州省' 
    WHEN cu.sf = '云南省' THEN
    '云南省' 
    WHEN cu.sf = '西藏自治区' THEN
    '西藏自治区' 
    WHEN cu.sf = '陕西省' THEN
    '陕西省' 
    WHEN cu.sf = '甘肃省' THEN
    '甘肃省' 
    WHEN cu.sf = '青海省' THEN
    '青海省' 
    WHEN cu.sf = '宁夏回族自治区' THEN
    '宁夏回族自治区' 
    WHEN cu.sf = '新疆维吾尔自治区' THEN
    '新疆维吾尔自治区' 
    WHEN cu.sf LIKE '%台湾省%' THEN
    '台湾省' 
    WHEN cu.sf LIKE '%香港%' THEN
    '香港特别行政区' 
    WHEN cu.sf LIKE '%澳门%' THEN
    '澳门特别行政区' ELSE NULL 
  END AS 收货省,
  m.vdef20 AS 收货地址,
  m.vdef8 AS 服务商,
  refsaleprice AS 商桥批发价,
  lowestprice AS 商桥限价,
CASE
    
    WHEN yw.busicode = 's005' THEN
    '放货' ELSE '销售' 
  END 是否放货 
FROM
  nc5x.so_saleinvoice ii
  LEFT JOIN (
  SELECT
    ib.csaleid,
    ib.nnumber,
    ib.nsummny,
    ch.invpinpai,
    ch.height,
    ch.width,
    ch.length,
    ch.invname,
    ch.invcode,
    ib.blargessflag,
    ch.pk_invbasdoc,
    ib.coriginalbillcode,
    ib.noriginalcurmny,
    lowestprice,
    refsaleprice,
    ch.unitvolume,
    ch.unitweight 
  FROM
    nc5x.so_saleinvoice_b ib
    JOIN nc5x.bd_invbasdoc ch ON ib.cinvbasdocid = ch.pk_invbasdoc
    JOIN nc5x.bd_invmandoc bb ON ch.pk_invbasdoc = bb.pk_invbasdoc 
  ) ib ON ib.csaleid = ii.csaleid
  LEFT JOIN nc5x.v_zlw_cust cu ON ii.creceiptcorpid = cu.pk_cumandoc
  LEFT JOIN nc5x.bd_busitype yw ON ii.cbiztype = yw.pk_busitype
  LEFT JOIN nc5x.bd_stordoc dd ON ii.cwarehouseid = dd.pk_stordoc
  LEFT JOIN nc5x.so_sale m ON ib.coriginalbillcode = m.vreceiptcode
  LEFT JOIN nc5x.sm_user w ON m.coperatorid = w.cuserid
  LEFT JOIN nc5x.bd_psndoc us ON us.pk_psndoc = ii.cemployeeid
  LEFT JOIN (
  SELECT
    bb.invcode,
    bb.invname,
    bb.width,
    bb.invpinpai,
    bb.length,
    bb.height,
  CASE
      
      WHEN gg.nabprice IS NULL THEN
      ( CASE WHEN gg.noutnum = 0 THEN 0 ELSE round( gg.noutmny / gg.noutnum, 2 ) END ) ELSE gg.nabprice 
    END nabprice,
  gg.cinventoryid 主键 
FROM
  nc5x.bd_invbasdoc bb
  JOIN (
  SELECT
    ee.pk_invmandoc,
    ff.cinventoryid,
    ee.pk_invbasdoc,
    ff.nabprice,
    ff.caccountmonth,
    ff.noutmny,
    ff.noutnum 
  FROM
    nc5x.bd_invmandoc ee
    JOIN nc5x.ia_generalledger ff ON ee.pk_invmandoc = ff.cinventoryid 
    AND ff.dr = 0 
  WHERE
    ee.dr = 0 
    AND ff.dr = 0 
  ) gg ON gg.pk_invbasdoc = bb.pk_invbasdoc 
WHERE
  bb.width IN ( '原装', '打印机', '兼容' ) 
  AND gg.caccountmonth <> '00' 
  AND bb.dr = 0 
  ) gp ON ib.invcode = gp.invcode 
WHERE
  length( ib.invcode )> 4 
  AND ii.dr = 0 
  AND ii.dbilldate >= to_char ( TRUNC ( sysdate - 31 ), 'yyyy-mm-dd' ) 
  AND ii.dbilldate <= to_char ( TRUNC ( sysdate - 1 ), 'yyyy-mm-dd' ) 
  AND ib.width IN ( '原装', '兼容', '打印机' )) da 
GROUP BY
  da.日期,
  da.市场部,
  da.仓库,
  da.收货省,
  da.大类 
ORDER BY
  da.日期,
  da.市场部,
  da.仓库,
  da.收货省,
  da.大类

# StarRocks 语法参考手册

> 基于 [StarRocks 3.5 官方文档](https://docs.starrocks.io/zh/docs/3.5/category/reference/)，  
> 聚焦本项目常用的数据类型、函数和SQL语法，避免写SQL时出现语法错误。

---

## 一、数据类型

### 1.1 数值类型

| 类型 | 字节 | 范围 | 用途 |
|------|------|------|------|
| `TINYINT` | 1 | -128 ~ 127 | 标志位（dr, blargessflag） |
| `SMALLINT` | 2 | -32768 ~ 32767 | — |
| `INT` | 4 | -2147483648 ~ 2147483647 | 数量、计数 |
| `BIGINT` | 8 | -2^63 ~ 2^63-1 | 主键、大数量 |
| `LARGEINT` | 16 | -2^127 ~ 2^127-1 | 超大整数 |
| `FLOAT` | 4 | 6~7位有效数字 | 近似计算 |
| `DOUBLE` | 8 | 15~16位有效数字 | 近似计算 |
| `DECIMAL(P,S)` | — | P最大38位 | **金额、单价**（推荐） |

> **项目建议**：金额字段优先用 `DECIMAL(18,2)` 或 `DECIMAL(20,4)`，避免浮点精度问题。

### 1.2 字符串类型

| 类型 | 最大长度 | 用途 |
|------|---------|------|
| `CHAR(N)` | 255字节 | 固定长度编码（如 pk_corp） |
| `VARCHAR(N)` | 1048576字节(1MB) | **最常用**：名称、编码、描述 |
| `STRING` | 65535字节 | 等价于 VARCHAR(65535) |

### 1.3 日期类型

| 类型 | 格式 | 范围 | 说明 |
|------|------|------|------|
| `DATE` | `YYYY-MM-DD` | 0000-01-01 ~ 9999-12-31 | 只有日期 |
| `DATETIME` | `YYYY-MM-DD HH:MM:SS` | 0000-01-01 00:00:00 ~ 9999-12-31 23:59:59 | 日期+时间 |

### 1.4 其他常用类型

| 类型 | 用途 |
|------|------|
| `BOOLEAN` | 布尔值 |
| `JSON` | 半结构化数据 |
| `ARRAY<T>` | 数组（3.0+） |

---

## 二、SELECT 语法结构

```sql
[ WITH cte_name AS ( query ) [, ...] ]
SELECT [ALL | DISTINCT] select_expr [, select_expr ...]
[FROM table_reference [, ...]]
[WHERE filter_condition]
[GROUP BY { expr | ROLLUP(expr_list) | CUBE(expr_list) | GROUPING SETS(expr_list) } [, ...]]
[HAVING having_condition]
[ORDER BY { col_name | expr } [ASC | DESC] [NULLS FIRST | NULLS LAST] [, ...]]
[LIMIT { row_count | ALL }]
[{ UNION [ALL] | INTERSECT | EXCEPT } (SELECT ...)]
```

### 2.1 JOIN 类型

```sql
-- 内连接（只返回匹配的行）
FROM A INNER JOIN B ON A.id = B.id

-- 左外连接（A的所有行 + B匹配的行）
FROM A LEFT [OUTER] JOIN B ON A.id = B.id

-- 右外连接
FROM A RIGHT [OUTER] JOIN B ON A.id = B.id

-- 全外连接
FROM A FULL [OUTER] JOIN B ON A.id = B.id

-- 交叉连接（笛卡尔积）
FROM A CROSS JOIN B
```

### 2.2 子查询

```sql
-- IN 子查询
WHERE id IN (SELECT id FROM ...)

-- EXISTS 子查询（性能更好）
WHERE EXISTS (SELECT 1 FROM ... WHERE ...)

-- 标量子查询
SELECT (SELECT MAX(price) FROM ...) AS max_price

-- FROM 子查询（派生表）
SELECT * FROM (SELECT ... GROUP BY ...) t
```

### 2.3 WITH (CTE 公用表表达式)

```sql
WITH monthly_sales AS (
    SELECT YEAR(dmakedate) AS y, MONTH(dmakedate) AS m, SUM(noriginalcurmny) AS total
    FROM SO_SQUAREDETAIL WHERE pk_corp='1006' AND dr=0
    GROUP BY YEAR(dmakedate), MONTH(dmakedate)
)
SELECT y, m, total,
    LAG(total) OVER (ORDER BY y, m) AS 上月销售
FROM monthly_sales;
```

### 2.4 集合操作

```sql
-- UNION ALL（不去重，性能更好）
SELECT ... FROM A
UNION ALL
SELECT ... FROM B

-- UNION（去重）
SELECT ... FROM A
UNION
SELECT ... FROM B

-- INTERSECT（交集） / EXCEPT（差集）
```

> **注意**：集合操作要求列数和类型一致。

---

## 三、类型转换

### 3.1 CAST 函数

```sql
CAST(expr AS type)
```

**本项目常用转换**：

```sql
-- 字符串→日期（必须！NC日期字段常为VARCHAR）
CAST(dbilldate AS DATE)
CAST('2024-01-01' AS DATE)

-- 字符串→整数（账期天数计算）
CAST(termid AS INT)
CAST('30' AS INT)

-- 数值→字符串
CAST(123 AS VARCHAR)

-- 整数→DECIMAL（金额精度）
CAST(price AS DECIMAL(18,2))
```

> **常见错误**：不做 CAST 直接对 VARCHAR 类型日期字段做日期运算，会导致类型不匹配报错。

---

## 四、日期时间函数

### 4.1 获取当前时间

| 函数 | 返回类型 | 说明 |
|------|---------|------|
| `CURRENT_DATE()` | DATE | 当前日期 |
| `CURRENT_TIMESTAMP()` / `NOW()` | DATETIME | 当前日期时间 |
| `CURDATE()` | DATE | 等价于 CURRENT_DATE() |
| `CURTIME()` | TIME | 当前时间 |
| `UNIX_TIMESTAMP()` | BIGINT | 当前Unix时间戳 |

### 4.2 日期加减

```sql
-- DATE_ADD / ADDDATE：日期加
DATE_ADD(date, INTERVAL expr type)
-- type: YEAR, QUARTER, MONTH, DAY, HOUR, MINUTE, SECOND, MILLISECOND, MICROSECOND

DATE_ADD(CAST(dbilldate AS DATE), INTERVAL 30 DAY)
DATE_ADD('2024-01-15', INTERVAL 2 MONTH)

-- DATE_SUB / SUBDATE：日期减
DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
```

### 4.3 日期差值

```sql
-- DATEDIFF：返回两个日期之间的天数差（date1 - date2）
DATEDIFF(date1, date2)
DATEDIFF(CURRENT_DATE(), CAST(dbilldate AS DATE))    -- 距今天数

-- TIMESTAMPDIFF：按指定单位返回差值
TIMESTAMPDIFF(MONTH, '2024-01-01', '2024-06-15')     -- 返回5

-- DAYS_DIFF：等价于DATEDIFF（StarRocks特有）
DAYS_DIFF('2024-03-01', '2024-01-01')                 -- 返回60
```

### 4.4 提取日期部分

```sql
YEAR(date)                    -- 年份（INT）
MONTH(date)                   -- 月份（INT，1-12）
DAY(date)                     -- 日（INT，1-31）
QUARTER(date)                 -- 季度（INT，1-4）
WEEK(date)                    -- 周数（INT）
HOUR(datetime)                -- 小时
MINUTE(datetime)              -- 分钟
SECOND(datetime)              -- 秒

DAYOFWEEK(date)               -- 星期几（1=周日, 7=周六）
DAYOFYEAR(date)               -- 一年中第几天
```

### 4.5 日期格式化

```sql
DATE_FORMAT(date, format)

-- 常用格式符
-- %Y: 四位年份    %m: 两位月份    %d: 两位日期
-- %H: 24小时制    %i: 分钟        %s: 秒
-- %T: 时:分:秒

DATE_FORMAT(dbilldate, '%Y-%m')           -- '2024-03'
DATE_FORMAT(dbilldate, '%Y年%m月%d日')     -- '2024年03月15日'
```

### 4.6 日期截断

```sql
-- DATE_TRUNC：按精度截断日期（物化视图分区常用）
DATE_TRUNC(fmt, datetime)
-- fmt: microsecond, millisecond, second, minute, hour, day, week, month, quarter, year

DATE_TRUNC('month', '2024-03-15 10:30:00')   -- '2024-03-01 00:00:00'
DATE_TRUNC('quarter', '2024-08-20')           -- '2024-07-01 00:00:00'
DATE_TRUNC('year', '2024-03-15')              -- '2024-01-01 00:00:00'
```

> **注意**：DATE 类型的 `date_trunc` 只支持 year/quarter/month/week/day，不支持 hour 及更小粒度。

### 4.7 其他日期函数

```sql
LAST_DAY(date)                -- 所在月份最后一天
MAKEDATE(year, dayofyear)     -- 根据年和天数生成日期
STR_TO_DATE(str, format)      -- 字符串解析为日期
FROM_UNIXTIME(timestamp)      -- Unix时间戳→DATETIME
```

---

## 五、字符串函数

### 5.1 常用函数

| 函数 | 说明 | 示例 |
|------|------|------|
| `LENGTH(str)` | 字节长度 | `LENGTH('中国')` → 6 |
| `CHAR_LENGTH(str)` | 字符长度 | `CHAR_LENGTH('中国')` → 2 |
| `SUBSTR(str, pos [,len])` | 截取子串（pos从1开始） | `SUBSTR('abcdef', 1, 2)` → `'ab'` |
| `SUBSTRING(str, pos [,len])` | 同SUBSTR | — |
| `LEFT(str, len)` | 左截取 | `LEFT('abcdef', 3)` → `'abc'` |
| `RIGHT(str, len)` | 右截取 | — |
| `CONCAT(s1, s2, ...)` | 拼接 | `CONCAT(invcode, '-', invname)` |
| `CONCAT_WS(sep, s1, s2, ...)` | 带分隔符拼接（跳过NULL） | `CONCAT_WS(',', 'a', NULL, 'b')` → `'a,b'` |
| `TRIM(str)` | 去两端空格 | — |
| `LTRIM(str)` / `RTRIM(str)` | 去左/右空格 | — |
| `UPPER(str)` / `LOWER(str)` | 大小写转换 | — |
| `REPLACE(str, from, to)` | 替换 | `REPLACE(invname, ' ', '')` |
| `LPAD(str, len, pad)` | 左填充 | `LPAD('5', 3, '0')` → `'005'` |
| `RPAD(str, len, pad)` | 右填充 | — |
| `REVERSE(str)` | 反转 | — |
| `SPLIT_PART(str, sep, n)` | 分割取第n部分 | `SPLIT_PART('a-b-c', '-', 2)` → `'b'` |
| `REGEXP_EXTRACT(str, pat, idx)` | 正则提取 | — |

### 5.2 模糊匹配

```sql
-- LIKE（%任意字符，_单个字符）
WHERE custname LIKE '%科技%'
WHERE invcode LIKE 'TH%'       -- 退货单
WHERE invcode NOT LIKE '98%'

-- REGEXP（正则）
WHERE invcode REGEXP '^98[0-9]{2}$'
```

---

## 六、数学函数

| 函数 | 说明 | 示例 |
|------|------|------|
| `ROUND(x [,d])` | **四舍五入**到d位小数 | `ROUND(3.1415, 2)` → `3.14` |
| `CEIL(x)` / `CEILING(x)` | 向上取整 | `CEIL(3.1)` → `4` |
| `FLOOR(x)` | 向下取整 | `FLOOR(3.9)` → `3` |
| `TRUNCATE(x, d)` | 截断到d位小数（不四舍五入） | `TRUNCATE(3.1415, 2)` → `3.14` |
| `ABS(x)` | 绝对值 | — |
| `MOD(x, y)` | 取模（y为0返回NULL） | `MOD(10, 3)` → `1` |
| `POWER(x, y)` / `POW(x, y)` | x的y次方 | — |
| `SQRT(x)` | 平方根 | — |
| `GREATEST(a, b, ...)` | 最大值 | `GREATEST(10, 20, 15)` → `20` |
| `LEAST(a, b, ...)` | 最小值 | — |
| `RAND()` | 随机数 0~1 | — |

---

## 七、条件函数

### 7.1 CASE WHEN

```sql
-- 简单形式
CASE expr
    WHEN value1 THEN result1
    WHEN value2 THEN result2
    ELSE default_result
END

-- 搜索形式（更灵活，本项目最常用）
CASE
    WHEN condition1 THEN result1
    WHEN condition2 THEN result2
    ELSE default_result
END
```

### 7.2 IF / IFNULL / NULLIF / COALESCE

```sql
-- IF(条件, 真值, 假值)
IF(blargessflag = 'Y', 0, nsummny) AS 金额

-- IFNULL(expr, default)：expr为NULL时返回default
IFNULL(blargessflag, 'N')
IFNULL(termid, '0')

-- NULLIF(a, b)：a=b时返回NULL，否则返回a
NULLIF(noutnum, 0)              -- 可用于除零保护：x / NULLIF(y, 0)

-- COALESCE(a, b, c, ...)：返回第一个非NULL值
COALESCE(gl.nabprice, invman.costprice, 0)
COALESCE(termid, '0')
```

> **项目技巧**：除零保护的简洁写法 → `ROUND(x / NULLIF(y, 0), 2)` 等价于 `CASE WHEN y=0 THEN NULL ELSE ROUND(x/y, 2) END`

---

## 八、聚合函数

| 函数 | 说明 | NULL处理 |
|------|------|---------|
| `COUNT(*)` | 行数 | 包含NULL行 |
| `COUNT(expr)` | 非NULL计数 | 忽略NULL |
| `COUNT(DISTINCT expr)` | 去重计数 | 忽略NULL |
| `SUM(expr)` | 求和 | 忽略NULL |
| `AVG(expr)` | 平均值 | 忽略NULL |
| `MAX(expr)` | 最大值 | 忽略NULL |
| `MIN(expr)` | 最小值 | 忽略NULL |
| `GROUP_CONCAT(expr [ORDER BY ... ] [SEPARATOR sep])` | 拼接为字符串 | 忽略NULL |
| `ARRAY_AGG(expr)` | 聚合为数组 | 包含NULL |

**GROUP BY 规则**：SELECT 中所有非聚合列必须出现在 GROUP BY 中。

```sql
-- ✅ 正确
SELECT dept.deptname, SUM(金额) FROM ... GROUP BY dept.deptname

-- ❌ 错误：psn.psnname 不在 GROUP BY 中
SELECT dept.deptname, psn.psnname, SUM(金额) FROM ... GROUP BY dept.deptname
```

**HAVING 与 WHERE 的区别**：
- `WHERE`：分组前过滤（不能用聚合函数）
- `HAVING`：分组后过滤（可以用聚合函数）

```sql
SELECT dept.deptname, SUM(金额) AS total
FROM ... WHERE dr = 0        -- WHERE 过滤原始行
GROUP BY dept.deptname
HAVING SUM(金额) > 100000;   -- HAVING 过滤分组结果
```

---

## 九、窗口函数

### 9.1 语法

```sql
FUNCTION(args) OVER (
    [PARTITION BY expr [, ...]]
    [ORDER BY expr [ASC|DESC] [, ...]]
    [ROWS | RANGE BETWEEN frame_start AND frame_end]
)
```

**窗口框架**：
- `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING` — 前1行到后1行
- `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` — 从分区开头到当前行
- `RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` — 整个分区

### 9.2 排名函数

```sql
-- ROW_NUMBER()：连续编号（1,2,3,4,5）
ROW_NUMBER() OVER (PARTITION BY dept ORDER BY 销售额 DESC) AS 排名

-- RANK()：并列跳号（1,2,2,4,5）
RANK() OVER (ORDER BY score DESC) AS 排名

-- DENSE_RANK()：并列不跳号（1,2,2,3,4）
DENSE_RANK() OVER (ORDER BY score DESC) AS 排名

-- NTILE(n)：分桶
NTILE(4) OVER (ORDER BY 销售额 DESC) AS 分组   -- 四分位
```

### 9.3 偏移函数

```sql
-- LAG(expr, offset, default)：向前偏移（上一行）
LAG(销售额, 1, 0) OVER (ORDER BY 月份) AS 上月销售额

-- LEAD(expr, offset, default)：向后偏移（下一行）
LEAD(销售额, 1, 0) OVER (ORDER BY 月份) AS 下月销售额

-- FIRST_VALUE / LAST_VALUE
FIRST_VALUE(closing_price) OVER (PARTITION BY stock ORDER BY date) AS 首日价
```

### 9.4 聚合窗口函数

```sql
-- 累计求和
SUM(销售额) OVER (PARTITION BY dept ORDER BY 月份
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS 累计销售

-- 移动平均
AVG(销售额) OVER (ORDER BY 月份
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS 三月移动平均
```

### 9.5 实用示例：同比环比

```sql
WITH monthly AS (
    SELECT DATE_FORMAT(dmakedate, '%Y-%m') AS 月份,
           SUM(noriginalcurmny) AS 销售额
    FROM SO_SQUAREDETAIL WHERE pk_corp = '1006' AND dr = 0
    GROUP BY DATE_FORMAT(dmakedate, '%Y-%m')
)
SELECT 月份, 销售额,
    LAG(销售额, 1)  OVER (ORDER BY 月份) AS 上月销售额,
    LAG(销售额, 12) OVER (ORDER BY 月份) AS 去年同月销售额,
    CASE WHEN LAG(销售额, 1) OVER (ORDER BY 月份) = 0 THEN 0
         ELSE ROUND((销售额 - LAG(销售额, 1) OVER (ORDER BY 月份)) 
              / LAG(销售额, 1) OVER (ORDER BY 月份) * 100, 2)
    END AS 环比增长率,
    CASE WHEN LAG(销售额, 12) OVER (ORDER BY 月份) = 0 THEN 0
         ELSE ROUND((销售额 - LAG(销售额, 12) OVER (ORDER BY 月份)) 
              / LAG(销售额, 12) OVER (ORDER BY 月份) * 100, 2)
    END AS 同比增长率
FROM monthly ORDER BY 月份;
```

---

## 十、DDL 常用语法

### 10.1 物化视图

```sql
-- 创建异步物化视图
CREATE MATERIALIZED VIEW [IF NOT EXISTS] mv_name
[COMMENT 'description']
[PARTITION BY date_trunc('month', date_col)]
DISTRIBUTED BY HASH(key_col) BUCKETS 32
REFRESH DEFERRED ASYNC EVERY (INTERVAL 1 DAY)
PROPERTIES (
    "enable_spill" = "true",
    "mv_rewrite_staleness_second" = "86400"
)
AS SELECT ...;

-- 刷新
REFRESH MATERIALIZED VIEW mv_name [FORCE] [WITH SYNC MODE];

-- 删除
DROP MATERIALIZED VIEW [IF EXISTS] mv_name;

-- 状态查看
SHOW MATERIALIZED VIEWS [LIKE 'pattern'];

-- 原子替换
ALTER MATERIALIZED VIEW old_mv SWAP WITH new_mv;
```

### 10.2 建表

```sql
CREATE TABLE [IF NOT EXISTS] table_name (
    col1 type1 [NULL | NOT NULL] [DEFAULT value] [COMMENT 'comment'],
    col2 type2,
    ...
)
ENGINE = OLAP
[KEY_TYPE (col1, col2, ...)]        -- DUPLICATE KEY / AGGREGATE KEY / UNIQUE KEY / PRIMARY KEY
COMMENT 'table comment'
DISTRIBUTED BY HASH(col) BUCKETS n
[PARTITION BY ...]
[PROPERTIES (...)];
```

---

## 十一、常见语法陷阱

### 11.1 NULL 的三值逻辑

```sql
-- NULL 参与比较运算的结果永远是 NULL（不是 TRUE/FALSE）
NULL = NULL     → NULL（不是 TRUE）
NULL <> 1       → NULL（不是 TRUE）
NULL AND TRUE   → NULL
NULL OR TRUE    → TRUE

-- 正确判断 NULL
WHERE col IS NULL
WHERE col IS NOT NULL

-- 聚合函数忽略 NULL，但 COUNT(*) 不忽略
COUNT(*)        -- 包含NULL行
COUNT(col)      -- 不包含NULL行
SUM(NULL_col)   -- 返回NULL（不是0）
```

### 11.2 除零错误

```sql
-- ❌ 报错或返回NULL
SELECT 100 / 0;

-- ✅ 方法1：CASE WHEN
CASE WHEN denominator = 0 THEN 0 ELSE ROUND(numerator / denominator, 2) END

-- ✅ 方法2：NULLIF（更简洁）
ROUND(numerator / NULLIF(denominator, 0), 2)
```

### 11.3 隐式类型转换

```sql
-- ❌ 字符串与数值比较可能导致意外结果
WHERE termid = 01    -- termid是VARCHAR，01会被转为整数1

-- ✅ 显式使用字符串
WHERE termid = '01'
```

### 11.4 GROUP BY 别名

```sql
-- StarRocks 支持在 GROUP BY 中使用列别名（MySQL不一定支持）
SELECT DATE_FORMAT(d, '%Y-%m') AS 月份, SUM(金额) FROM ...
GROUP BY 月份     -- ✅ StarRocks 支持

-- 但 WHERE 子句中不能使用 SELECT 别名
-- ❌ WHERE 月份 = '2024-01'
-- ✅ WHERE DATE_FORMAT(d, '%Y-%m') = '2024-01'
```

### 11.5 DISTINCT 与 ORDER BY

```sql
-- ❌ ORDER BY 的列必须在 SELECT DISTINCT 列表中
SELECT DISTINCT dept FROM t ORDER BY name;  -- 错误

-- ✅ 
SELECT DISTINCT dept FROM t ORDER BY dept;
```

### 11.6 LIMIT 与 OFFSET

```sql
-- 取前10行
LIMIT 10

-- 跳过前20行取10行（分页）
LIMIT 10 OFFSET 20
-- 或
LIMIT 20, 10
```

---

## 十二、官方文档链接

| 主题 | URL |
|------|-----|
| 参考手册首页 | https://docs.starrocks.io/zh/docs/3.5/category/reference/ |
| 日期函数 | https://docs.starrocks.io/zh/docs/sql-reference/sql-functions/date-time-functions/ |
| 字符串函数 | https://docs.starrocks.io/zh/docs/sql-reference/sql-functions/string-functions/ |
| 数学函数 | https://docs.starrocks.io/zh/docs/sql-reference/sql-functions/math-functions/ |
| 聚合函数 | https://docs.starrocks.io/zh/docs/sql-reference/sql-functions/aggregate-functions/ |
| 窗口函数 | https://docs.starrocks.io/zh/docs/sql-reference/sql-functions/Window_function/ |
| 条件函数 | https://docs.starrocks.io/zh/docs/sql-reference/sql-functions/condition-functions/ |
| 物化视图 | https://docs.starrocks.io/zh/docs/3.5/using_starrocks/async_mv/use-cases/ |
| 系统变量 | https://docs.starrocks.io/zh/docs/3.5/reference/System_variable/ |

---

**SQL编码规范**: `docs/SQL编码规范.md`  
**业务SQL模板**: `docs/业务场景SQL模板.md`  
**数据字典**: `docs/数据字典.md`

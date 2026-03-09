# SetMiner

## 启动方式

### 一键启动

根目录已提供一键启动脚本：

```powershell
python -m start_setminer --port 5555
```

Windows 下也可以直接双击：

```powershell
start_setminer.bat
```

说明：

- 默认采用单端口托管模式：由一个 `uvicorn` 进程同时提供后端 API 和 `frontend/dist` 前端静态文件
- 默认访问方式可写成 `python -m start_setminer --port 5000`
- 也支持直接使用 `uvicorn` 托管：

```powershell
python -m uvicorn start_setminer:app --host 127.0.0.1 --port 5555
```

- 单端口模式启动前，请先在 `frontend` 目录执行一次 `npm run build`
- 如只想检查环境是否齐全，可执行 `python -m start_setminer --check-only`
- `start_setminer.bat` 默认会调用 `python -m start_setminer`，并支持透传额外参数

### 开发模式

如果希望以前后端分离、便于热更新调试，可直接一行命令启动：

```powershell
python -m start_setminer --dev
```

默认地址：

- 前端：`http://127.0.0.1:5173`
- 后端：`http://127.0.0.1:18000`

Windows 下也可以直接双击：

```powershell
start_setminer_dev.bat
```

说明：

- 该模式会同时启动后端 `uvicorn --reload` 和前端 `vite dev`
- 修改后端代码时会自动重载后端
- 修改前端代码时会自动热更新页面，无需重新构建 `frontend/dist`
- `--same-window` 模式下会在当前终端持续输出前后端日志，并附加 `[backend]` / `[frontend]` 前缀，按 `Ctrl+C` 可一起停止
- 如只想检查开发环境是否齐全，可执行 `python -m start_setminer --dev --check-only`
- 如需自定义端口，可执行：

```powershell
python -m start_setminer --dev --backend-port 18001 --frontend-port 5174
```

### 后端

```powershell
cd backend
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```

### 前端

```powershell
cd frontend
npm install
npm run dev
```

## ERP 导入格式

支持 `csv / xlsx / xls`，建议至少包含以下列：

- `user_id`
- `user_name`
- `permission_id`
- `permission_name`

可选列：

- `permission_group`
- `permission_type`
- `parent_permission_id`
- `permission_level`
- `sod_conflict_code`
- `sod_conflict_level`
- `permission_path`

新增约束列说明：

- `parent_permission_id`：菜单-按钮父子依赖，按钮应指向所属父菜单
- `permission_level`：建议填 `menu` / `button`
- `sod_conflict_code`：职责分离冲突组编码，同组权限参与冲突检查
- `sod_conflict_level`：建议填 `hard` / `soft`
- `permission_path`：可选展示路径，便于结果解释

兼容策略：

- 没有 `parent_permission_id` 时，不做父子依赖校验
- 没有 `sod_conflict_*` 时，不做 SoD 冲突校验
- 系统会对“用户拥有按钮但缺少父菜单”的输入自动补齐父菜单，并在结果页展示修复记录

工作区已提供示例模板：

- `dem_permissions/setminer_erp_import_template.csv`

另外还提供了可直接上传测试的 ERP 演示文件：

- `dem_permissions/setminer_erp_menu_only_demo.csv`
- `dem_permissions/setminer_erp_menu_button_sod_demo.csv`

其中：

- `setminer_erp_menu_only_demo.csv`：仅包含菜单权限，适合验证“纯菜单角色”场景
- `setminer_erp_menu_button_sod_demo.csv`：包含菜单、按钮、父子依赖和 SoD 规则，适合验证约束接入后的完整链路

## 现状角色差异分析

如果希望对比“现状角色 vs 推荐角色”，可以在 ERP 页面额外上传：

- `dem_permissions/setminer_current_role_permissions_template.csv`
- `dem_permissions/setminer_current_user_roles_template.csv`

也提供了与约束演示数据配套的现状角色文件：

- `dem_permissions/setminer_current_role_permissions_demo.csv`
- `dem_permissions/setminer_current_user_roles_demo.csv`

其中现状角色权限文件建议至少包含：

- `role_id`
- `role_name`
- `permission_id`
- `permission_name`

如需在差异分析中识别现状角色的父子依赖违规和 SoD 冲突，建议同步提供与主权限文件一致的可选约束列：

- `permission_group`
- `permission_type`
- `parent_permission_id`
- `permission_level`
- `sod_conflict_code`
- `sod_conflict_level`
- `permission_path`

现状用户角色文件建议至少包含：

- `user_id`
- `user_name`
- `role_id`
- `role_name`

## SQL 批量导入

SQL 场景支持一次上传多个 `.sql` 文件，系统会提取：

- `SELECT` 字段
- `FROM / JOIN` 来源表
- 字段到来源表的归属线索

另外，上传后会先执行一轮 SQL 预处理，再进入字段解析与宽表分析流程。

### SQL 预处理能力

当前已支持自动识别并展开以下对象定义：

- `CREATE VIEW ... AS SELECT ...`
- `CREATE MATERIALIZED VIEW ... AS SELECT ...`
- `CREATE TABLE ... AS SELECT ...`（宽表 / CTAS）

如果报表 SQL、分析 SQL 引用了这些对象，系统会在预处理阶段尽量自动还原到底层查询，再继续做后续解析。当前能力包括：

- 支持跨文件收集视图、物化视图、宽表定义
- 支持递归展开多层引用
- 支持本地 `CTE` 同名遮蔽，避免误把局部对象当成外部视图展开
- 支持检测循环依赖，发现环路时停止继续展开并给出提示

这意味着现在上传 SQL 时，推荐把“报表 SQL”和它依赖的“视图 / 物化视图 / 宽表定义 SQL”一起上传。

工作区已提供演示 SQL：

- `demo_sql/sales_daily.sql`
- `demo_sql/refund_report.sql`
- `demo_sql/cte_customer_metrics.sql`
- `demo_sql/subquery_refund_ratio.sql`

重要说明：

- **如果 SQL 引用了视图、物化视图或宽表，请一并上传对应定义 SQL 文件**：系统会优先做对象展开，还原更底层的查询来源
- **禁止使用 `SELECT *`**：必须显式指定列名，如 `SELECT col1, col2, col3 FROM table`，否则无法准确识别字段归属
- **禁止使用裸列名**：在多表 JOIN 场景下，列名必须显式指定表名前缀，如 `SELECT t1.col1, t2.col2 FROM table1 t1 JOIN table2 t2`。裸列名（如直接写 `col1`）会导致静态解析器无法确定字段归属哪张表

### 预校验结果说明

SQL 预校验页面除了常规告警外，还会额外展示“对象展开预处理”摘要，便于快速确认上传内容是否被系统正确识别。当前会展示：

- 识别到的可展开对象列表
- 哪些 SQL 文件实际发生了对象展开
- 每个文件的最大展开层级
- 循环依赖链路

说明：

- 如果某个报表 SQL 没有展开到预期对象，请检查是否一并上传了对应定义文件
- 当前“最大展开层级”的口径是：相对当前 SQL，向下额外展开了多少层对象
- 例如：报表 SQL 直接引用一个视图，记为 `1` 层；若是“宽表 -> 物化视图 -> 视图”，则记为 `2` 层

## AI 模型配置

如需接入 AI 大模型进行分析，请在项目根目录创建 `.env` 文件（可参考 `.env.example`）。

配置格式如下：

```env
{NAME}_ENABLED=true
{NAME}_ENDPOINT=openai
{NAME}_API_KEY=your_api_key_here
{NAME}_API_BASE=https://api.example.com/v1
{NAME}_MODELS=model-name-1,model-name-2
```

示例（DeepSeek）：

```env
DEEPSEEK_ENABLED=true
DEEPSEEK_ENDPOINT=openai
DEEPSEEK_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DEEPSEEK_API_BASE=https://api.deepseek.com
DEEPSEEK_MODELS=deepseek-chat
```

示例（阿里云百炼 / Qwen）：

```env
QWEN_ENABLED=true
QWEN_ENDPOINT=openai
QWEN_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
QWEN_API_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1
QWEN_MODELS=qwen3-omni-flash,qwen3.5-plus,qwen3.5-flash
```

说明：

- 每个 provider 独立一组配置，互不干扰
- 密钥仅存于服务端，不会发送到前端
- 支持多个 provider 同时启用


import { useEffect, useMemo, useState } from 'react'
import {
  Alert,
  Button,
  Card,
  Col,
  Collapse,
  Descriptions,
  List,
  Radio,
  Row,
  Space,
  Statistic,
  Tabs,
  Tag,
  Tooltip,
  Typography,
} from 'antd'
import { CheckCircleOutlined, InfoCircleOutlined, ReloadOutlined, UploadOutlined } from '@ant-design/icons'

import './App.css'
import { AssignmentsTable } from './components/AssignmentsTable'
import { ConstraintReportView } from './components/ConstraintReportView'
import GraphView from './components/GraphView'
import { RoleDiffView } from './components/RoleDiffView'
import { UnitsTable } from './components/UnitsTable'
import {
  fetchDemoSolution,
  fetchScenes,
  previewErpFile,
  previewSqlFiles,
  solveErpFile,
  solveSqlFiles,
} from './services/api'
import type { ImportPreviewResponse, SceneInfo, SceneKey, SolveResponse } from './types/api'

import { Layout } from 'antd'
const { Title, Text } = Typography

const ERP_COLS_REQUIRED = ['user_id', 'user_name', 'permission_id', 'permission_name']
const ERP_COLS_OPTIONAL = [
  'permission_group', 'permission_type', 'parent_permission_id',
  'permission_level', 'sod_conflict_code', 'sod_conflict_level', 'permission_path',
]

const SQL_IMPORT_NOTES = [
  {
    title: '不要直接上传视图定义文件',
    detail: '如果 SQL 中引用了视图，请同时提供视图的原始 SQL，以便分析真正的底层原始表',
  },
  {
    title: '禁止使用 SELECT *',
    detail: '必须显式指定列名，如 SELECT col1, col2, col3 FROM table，否则无法准确识别字段归属',
  },
  {
    title: '禁止使用裸列名',
    detail: '在多表 JOIN 场景下，列名必须显式指定表名前缀，如 SELECT t1.col1, t2.col2 FROM table1 t1 JOIN table2 t2。裸列名（如直接写 col1）会导致静态解析器无法确定字段归属哪张表',
  },
] as const

type WarningGroupKey = 'auto_fix' | 'warning' | 'excluded' | 'other'

function classifyWarning(item: string): WarningGroupKey {
  if (item.startsWith('[自动修复]')) return 'auto_fix'
  if (item.startsWith('[警告]')) return 'warning'
  if (item.startsWith('[排除]')) return 'excluded'
  if (item.startsWith('⚠')) return 'warning'
  return 'other'
}

function WarningGroups({ warnings, emptyText }: { warnings: string[]; emptyText: string }) {
  if (warnings.length === 0) {
    return <Text type="secondary" style={{ fontSize: 12 }}>{emptyText}</Text>
  }

  const grouped = warnings.reduce<Record<WarningGroupKey, string[]>>((acc, item) => {
    acc[classifyWarning(item)].push(item)
    return acc
  }, {
    auto_fix: [],
    warning: [],
    excluded: [],
    other: [],
  })

  const sections: Array<{ key: WarningGroupKey; title: string; type: 'success' | 'warning' | 'error' | 'info'; items: string[] }> = [
    { key: 'auto_fix', title: '自动修复', type: 'success', items: grouped.auto_fix },
    { key: 'warning', title: '警告', type: 'warning', items: grouped.warning },
    { key: 'excluded', title: '排除', type: 'error', items: grouped.excluded },
    { key: 'other', title: '其他提示', type: 'info', items: grouped.other },
  ]

  return (
    <Space direction="vertical" size={8} style={{ width: '100%', marginTop: 8 }}>
      {sections.filter((section) => section.items.length > 0).map((section) => (
        <Card
          key={section.key}
          size="small"
          type="inner"
          title={<span style={{ fontSize: 12, fontWeight: 600 }}>{section.title}</span>}
          styles={{ body: { padding: 10 } }}
        >
          <Space direction="vertical" size={6} style={{ width: '100%' }}>
            {section.items.map((item, idx) => (
              <Alert
                key={`${section.key}-${idx}`}
                type={section.type}
                showIcon
                message={<span style={{ fontSize: 12 }}>{item}</span>}
                style={{ padding: '4px 8px' }}
              />
            ))}
          </Space>
        </Card>
      ))}
    </Space>
  )
}

function App() {
  const [scenes, setScenes] = useState<SceneInfo[]>([])
  const [scene, setScene] = useState<SceneKey>('erp')
  // 每个场景独立保存结果，切换时不清空
  const [results, setResults] = useState<Partial<Record<SceneKey, SolveResponse>>>({})
  const [preview, setPreview] = useState<ImportPreviewResponse | null>(null)
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [sqlFiles, setSqlFiles] = useState<File[]>([])
  const [currentRoleFile, setCurrentRoleFile] = useState<File | null>(null)
  const [currentUserRoleFile, setCurrentUserRoleFile] = useState<File | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  // 按钮状态：idle = 未分析/已换文件，done = 分析完成
  const [analyzeStatus, setAnalyzeStatus] = useState<'idle' | 'done'>('idle')
  const [diffAnalyzeStatus, setDiffAnalyzeStatus] = useState<'idle' | 'done'>('idle')

  const result = results[scene] ?? null

  useEffect(() => {
    async function bootstrap() {
      setLoading(true)
      setError(null)
      try {
        const sceneList = await fetchScenes()
        setScenes(sceneList)
        const initialScene = sceneList[0]?.key ?? 'erp'
        setScene(initialScene)
        const demoResult = await fetchDemoSolution(initialScene)
        setResults(prev => ({ ...prev, [initialScene]: demoResult }))
      } catch {
        setError('无法连接后端服务，请先启动 FastAPI。')
      } finally {
        setLoading(false)
      }
    }
    void bootstrap()
  }, [])

  async function handleSceneChange(nextScene: SceneKey) {
    setScene(nextScene)
    setPreview(null)
    setSelectedFile(null)
    setSqlFiles([])
    setCurrentRoleFile(null)
    setCurrentUserRoleFile(null)
    setAnalyzeStatus('idle')
    setDiffAnalyzeStatus('idle')
    // 如果该场景已有结果则直接展示，无需重新请求演示数据
    if (results[nextScene]) {
      setError(null)
      return
    }
    setLoading(true)
    setError(null)
    try {
      const demoResult = await fetchDemoSolution(nextScene)
      setResults(prev => ({ ...prev, [nextScene]: demoResult }))
    } catch {
      setError('切换场景失败，请确认后端接口正常。')
    } finally {
      setLoading(false)
    }
  }

  async function handleRefreshDemo() {
    setLoading(true)
    setError(null)
    try {
      const demoResult = await fetchDemoSolution(scene)
      setResults(prev => ({ ...prev, [scene]: demoResult }))
    } catch {
      setError('切换场景失败，请确认后端接口正常。')
    } finally {
      setLoading(false)
    }
  }

  async function handlePreviewUpload() {
    if (scene === 'erp' && !selectedFile) { setError('请先选择 ERP 用户权限文件。'); return }
    if (scene === 'sql' && sqlFiles.length === 0) { setError('请先选择一个或多个 SQL 文件。'); return }
    setLoading(true); setError(null)
    try {
      const previewData = scene === 'erp'
        ? await previewErpFile(selectedFile as File)
        : await previewSqlFiles(sqlFiles)
      setPreview(previewData)
    } catch {
      setError(scene === 'erp' ? '文件预校验失败，请检查列名和文件格式。' : 'SQL 文件预校验失败，请检查文件格式。')
    } finally { setLoading(false) }
  }

  async function handleAnalyzeUpload() {
    if (scene === 'erp' && !selectedFile) { setError('请先选择 ERP 用户权限文件。'); return }
    if (scene === 'sql' && sqlFiles.length === 0) { setError('请先选择一个或多个 SQL 文件。'); return }
    setLoading(true); setError(null)
    try {
      const solved = scene === 'erp'
        ? await solveErpFile(selectedFile as File)
        : await solveSqlFiles(sqlFiles)
      setResults(prev => ({ ...prev, [scene]: solved }))
      setAnalyzeStatus('done')
    } catch (err: unknown) {
      const axiosErr = err as { response?: { status?: number; data?: { detail?: string } }; message?: string }
      const detail = axiosErr?.response?.data?.detail
      const status = axiosErr?.response?.status
      const msg = axiosErr?.message
      if (detail) {
        setError(`分析失败（${status ?? '?'}）：${detail}`)
      } else if (status) {
        setError(`分析失败，服务器返回 ${status}，请检查文件格式或后端接口。`)
      } else {
        setError(`分析失败：${msg ?? '未知错误'}，请检查文件格式或后端接口。`)
      }
    } finally { setLoading(false) }
  }

  async function handleAnalyzeWithDiff() {
    if (!selectedFile) { setError('请先选择 ERP 用户权限文件。'); return }
    setLoading(true); setError(null)
    try {
      const solved = await solveErpFile(selectedFile, currentRoleFile, currentUserRoleFile)
      setResults(prev => ({ ...prev, [scene]: solved }))
      setDiffAnalyzeStatus('done')
    } catch (err: unknown) {
      const axiosErr = err as { response?: { status?: number; data?: { detail?: string } }; message?: string }
      const detail = axiosErr?.response?.data?.detail
      const status = axiosErr?.response?.status
      const msg = axiosErr?.message
      if (detail) {
        setError(`分析失败（${status ?? '?'}）：${detail}`)
      } else if (status) {
        setError(`分析失败，服务器返回 ${status}，请检查文件格式或后端接口。`)
      } else {
        setError(`分析失败：${msg ?? '未知错误'}，请检查文件格式或后端接口。`)
      }
    } finally { setLoading(false) }
  }

  const activeScene = useMemo(
    () => scenes.find((item) => item.key === scene),
    [scene, scenes],
  )

  const siderContent = (
    <Space direction="vertical" size={12} style={{ width: '100%' }}>
      {/* 场景选择 */}
      <Card size="small" className="ctrl-card">
        <Space direction="vertical" size={8} style={{ width: '100%' }}>
          <div className="ctrl-card-title">
            <Text strong>分析场景</Text>
            {activeScene && (
              <Tooltip title={activeScene.description}>
                <InfoCircleOutlined style={{ color: '#8c8c8c', cursor: 'pointer' }} />
              </Tooltip>
            )}
          </div>
          <Radio.Group
            value={scene}
            onChange={(e) => void handleSceneChange(e.target.value as SceneKey)}
            optionType="button"
            buttonStyle="solid"
            size="middle"
            style={{ display: 'flex', width: '100%' }}
          >
            {scenes.map((item) => (
              <Radio.Button key={item.key} value={item.key} style={{ flex: 1, textAlign: 'center', fontSize: 14, fontWeight: 500 }}>
                {item.name}
              </Radio.Button>
            ))}
          </Radio.Group>
          {activeScene && scene !== 'sql' && (
            <Text type="secondary" style={{ fontSize: 12 }}>{activeScene.goal}</Text>
          )}
          {scene === 'sql' && (
            <div
              style={{
                border: '1px solid #ffe58f',
                background: '#fffbe6',
                borderRadius: 8,
                padding: '10px 12px',
              }}
            >
              <Text strong style={{ display: 'block', fontSize: 12, marginBottom: 6 }}>重要说明：</Text>
              <Space direction="vertical" size={6} style={{ width: '100%' }}>
                {SQL_IMPORT_NOTES.map((note) => (
                  <Text key={note.title} style={{ fontSize: 12, color: '#595959', lineHeight: 1.7 }}>
                    <Text strong style={{ fontSize: 12 }}>{note.title}</Text>
                    ：{note.detail}
                  </Text>
                ))}
              </Space>
            </div>
          )}
          <Button
            size="middle"
            icon={<ReloadOutlined />}
            onClick={() => void handleRefreshDemo()}
            loading={loading}
            disabled={loading}
            block
            style={{ marginTop: 2 }}
          >
            重新计算演示结果
          </Button>
        </Space>
      </Card>

      {/* ERP 文件导入 */}
      {scene === 'erp' && (
        <Card size="small" className="ctrl-card" title={<Text strong style={{ fontSize: 13 }}>导入 ERP 权限文件</Text>}>
          <Space direction="vertical" size={14} style={{ width: '100%' }}>

            {/* 格式说明 */}
            <div className="upload-hint-block">
              <Text style={{ fontSize: 12, color: '#595959', display: 'block', marginBottom: 6 }}>
                支持 <Text code style={{ fontSize: 11 }}>csv</Text> / <Text code style={{ fontSize: 11 }}>xlsx</Text> / <Text code style={{ fontSize: 11 }}>xls</Text>，必须包含以下列：
              </Text>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
                {ERP_COLS_REQUIRED.map((c) => (
                  <Tag key={c} color="blue" style={{ fontSize: 11, margin: 0 }}>{c}</Tag>
                ))}
              </div>
              <Tooltip
                title={
                  <div style={{ fontSize: 12, lineHeight: 1.8 }}>
                    <div style={{ fontWeight: 600, marginBottom: 4 }}>可选列：</div>
                    {ERP_COLS_OPTIONAL.map((c) => <Tag key={c} color="geekblue" style={{ marginBottom: 3 }}>{c}</Tag>)}
                    <div style={{ marginTop: 6, color: 'rgba(255,255,255,0.75)' }}>
                      parent_permission_id：菜单-按钮父子依赖<br />
                      sod_conflict_level：建议填 hard 或 soft
                    </div>
                  </div>
                }
                overlayStyle={{ maxWidth: 280 }}
              >
                <Text style={{ fontSize: 11, color: '#1677ff', cursor: 'pointer', marginTop: 6, display: 'inline-flex', alignItems: 'center', gap: 3 }}>
                  <InfoCircleOutlined /> 查看可选列说明
                </Text>
              </Tooltip>
            </div>

            {/* 主文件上传区 */}
            <div className="upload-drop-zone" style={loading ? { opacity: 0.45, pointerEvents: 'none' } : {}}>
              <label className="upload-drop-label">
                <input
                  type="file"
                  accept=".csv,.xlsx,.xls"
                  disabled={loading}
                  style={{ display: 'none' }}
                  onChange={(e) => {
                    setSelectedFile(e.target.files?.[0] ?? null)
                    setPreview(null)
                    setAnalyzeStatus('idle')
                    setDiffAnalyzeStatus('idle')
                  }}
                />
                {selectedFile ? (
                  <div className="upload-drop-selected">
                    <span className="upload-drop-icon">✓</span>
                    <Text style={{ fontSize: 12, color: '#389e0d', fontWeight: 500 }}>{selectedFile.name}</Text>
                    <Text style={{ fontSize: 11, color: '#8c8c8c' }}>点击重新选择</Text>
                  </div>
                ) : (
                  <div className="upload-drop-placeholder">
                    <UploadOutlined style={{ fontSize: 20, color: '#bfbfbf' }} />
                    <Text style={{ fontSize: 12, color: '#8c8c8c' }}>点击选择权限文件</Text>
                    <Text style={{ fontSize: 11, color: '#bfbfbf' }}>csv / xlsx / xls</Text>
                  </div>
                )}
              </label>
            </div>

            {/* 对比现状角色折叠区 */}
            <Collapse
              size="small"
              ghost
              className="diff-collapse"
              items={[{
                key: 'diff',
                label: (
                  <Text style={{ fontSize: 12, color: '#595959' }}>
                    对比现状角色 <Text style={{ fontSize: 11, color: '#bfbfbf' }}>（可选）</Text>
                  </Text>
                ),
                children: (
                  <Space direction="vertical" size={10} style={{ width: '100%' }}>
                    <div>
                      <Text style={{ fontSize: 11, color: '#8c8c8c', display: 'block', marginBottom: 4 }}>
                        现状角色权限文件 <Text code style={{ fontSize: 10 }}>role_id / permission_id</Text>
                      </Text>
                      <div className="upload-drop-zone upload-drop-zone--sm" style={loading ? { opacity: 0.45, pointerEvents: 'none' } : {}}>
                        <label className="upload-drop-label">
                          <input
                            type="file"
                            accept=".csv,.xlsx,.xls"
                            disabled={loading}
                            style={{ display: 'none' }}
                            onChange={(e) => setCurrentRoleFile(e.target.files?.[0] ?? null)}
                          />
                          {currentRoleFile ? (
                            <div className="upload-drop-selected">
                              <span className="upload-drop-icon">✓</span>
                              <Text style={{ fontSize: 11, color: '#389e0d', fontWeight: 500 }}>{currentRoleFile.name}</Text>
                            </div>
                          ) : (
                            <div className="upload-drop-placeholder">
                              <Text style={{ fontSize: 11, color: '#bfbfbf' }}>点击选择文件</Text>
                            </div>
                          )}
                        </label>
                      </div>
                    </div>
                    <div>
                      <Text style={{ fontSize: 11, color: '#8c8c8c', display: 'block', marginBottom: 4 }}>
                        现状用户角色文件 <Text code style={{ fontSize: 10 }}>user_id / role_id</Text>
                      </Text>
                      <div className="upload-drop-zone upload-drop-zone--sm" style={loading ? { opacity: 0.45, pointerEvents: 'none' } : {}}>
                        <label className="upload-drop-label">
                          <input
                            type="file"
                            accept=".csv,.xlsx,.xls"
                            disabled={loading}
                            style={{ display: 'none' }}
                            onChange={(e) => setCurrentUserRoleFile(e.target.files?.[0] ?? null)}
                          />
                          {currentUserRoleFile ? (
                            <div className="upload-drop-selected">
                              <span className="upload-drop-icon">✓</span>
                              <Text style={{ fontSize: 11, color: '#389e0d', fontWeight: 500 }}>{currentUserRoleFile.name}</Text>
                            </div>
                          ) : (
                            <div className="upload-drop-placeholder">
                              <Text style={{ fontSize: 11, color: '#bfbfbf' }}>点击选择文件</Text>
                            </div>
                          )}
                        </label>
                      </div>
                    </div>
                  </Space>
                ),
              }]}
            />

            <Space direction="vertical" size={6} style={{ width: '100%' }}>
              <Button block onClick={() => void handlePreviewUpload()} disabled={!selectedFile || loading} loading={loading && analyzeStatus === 'idle'} icon={<InfoCircleOutlined />}>
                预校验文件
              </Button>
              <Button
                block
                type="primary"
                icon={analyzeStatus === 'done' ? <CheckCircleOutlined /> : <UploadOutlined />}
                onClick={() => void handleAnalyzeUpload()}
                disabled={!selectedFile || loading}
                loading={loading}
                style={analyzeStatus === 'done' ? { background: '#52c41a', borderColor: '#52c41a' } : {}}
              >
                {analyzeStatus === 'done' ? '分析完成（重新分析）' : '上传并分析'}
              </Button>
              <Button
                block
                type="dashed"
                onClick={() => void handleAnalyzeWithDiff()}
                disabled={!selectedFile || !currentRoleFile || loading}
                loading={loading}
                icon={diffAnalyzeStatus === 'done' ? <CheckCircleOutlined /> : <ReloadOutlined />}
                style={diffAnalyzeStatus === 'done' ? { color: '#52c41a', borderColor: '#52c41a' } : {}}
              >
                {diffAnalyzeStatus === 'done' ? '对比完成（重新对比）' : '分析并对比现状角色'}
              </Button>
            </Space>

            {preview && (
              <Card size="small" type="inner" title="预校验结果">
                <Descriptions column={1} size="small">
                  <Descriptions.Item label="用户数">{preview.entity_count}</Descriptions.Item>
                  <Descriptions.Item label="权限数">{preview.item_count}</Descriptions.Item>
                  <Descriptions.Item label="关系数">{preview.relation_count}</Descriptions.Item>
                </Descriptions>
                <Text style={{ fontSize: 11 }}>
                  列映射：{Object.entries(preview.detected_columns).map(([k, v]) => (
                    <Tag key={k} style={{ fontSize: 10 }}>{k}→{v}</Tag>
                  ))}
                </Text>
                <WarningGroups warnings={preview.warnings} emptyText="文件结构良好" />
              </Card>
            )}
          </Space>
        </Card>
      )}

      {/* SQL 文件导入 */}
      {scene === 'sql' && (
        <Card size="small" className="ctrl-card" title={<Text strong style={{ fontSize: 13 }}>批量导入 SQL 文件</Text>}>
          <Space direction="vertical" size={14} style={{ width: '100%' }}>
            <Text style={{ fontSize: 12, color: '#595959' }}>
              支持多个 <Text code style={{ fontSize: 11 }}>.sql</Text> / <Text code style={{ fontSize: 11 }}>.txt</Text> 文件，系统自动提取字段、来源表和 JOIN 线索。
            </Text>
            <div className="upload-drop-zone" style={loading ? { opacity: 0.45, pointerEvents: 'none' } : {}}>
              <label className="upload-drop-label">
                <input
                  type="file"
                  accept=".sql,.txt"
                  multiple
                  disabled={loading}
                  style={{ display: 'none' }}
                  onChange={(e) => {
                    setSqlFiles(Array.from(e.target.files ?? []))
                    setPreview(null)
                    setAnalyzeStatus('idle')
                  }}
                />
                {sqlFiles.length > 0 ? (
                  <div className="upload-drop-selected upload-drop-selected--files">
                    <span className="upload-drop-icon">✓</span>
                    <Text style={{ fontSize: 12, color: '#389e0d', fontWeight: 500 }}>已选 {sqlFiles.length} 个文件</Text>
                    <div className="upload-file-list" title={sqlFiles.map((f) => f.name).join('、')}>
                      <Text style={{ fontSize: 11, color: '#8c8c8c' }}>{sqlFiles.map((f) => f.name).join('、')}</Text>
                    </div>
                    <Text style={{ fontSize: 11, color: '#bfbfbf' }}>点击重新选择</Text>
                  </div>
                ) : (
                  <div className="upload-drop-placeholder">
                    <UploadOutlined style={{ fontSize: 20, color: '#bfbfbf' }} />
                    <Text style={{ fontSize: 12, color: '#8c8c8c' }}>点击选择 SQL 文件</Text>
                    <Text style={{ fontSize: 11, color: '#bfbfbf' }}>支持多选，.sql / .txt</Text>
                  </div>
                )}
              </label>
            </div>
            <Space direction="vertical" size={6} style={{ width: '100%' }}>
              <Button block onClick={() => void handlePreviewUpload()} disabled={sqlFiles.length === 0 || loading} loading={loading && analyzeStatus === 'idle'} icon={<InfoCircleOutlined />}>
                预校验 SQL
              </Button>
              <Button
                block
                type="primary"
                icon={analyzeStatus === 'done' ? <CheckCircleOutlined /> : <UploadOutlined />}
                onClick={() => void handleAnalyzeUpload()}
                disabled={sqlFiles.length === 0 || loading}
                loading={loading}
                style={analyzeStatus === 'done' ? { background: '#52c41a', borderColor: '#52c41a' } : {}}
              >
                {analyzeStatus === 'done' ? '分析完成（重新分析）' : '上传并分析 SQL'}
              </Button>
            </Space>
            {preview && (
              <Card size="small" type="inner" title="预校验结果">
                <Descriptions column={1} size="small">
                  <Descriptions.Item label="SQL 数">{preview.entity_count}</Descriptions.Item>
                  <Descriptions.Item label="字段数">{preview.item_count}</Descriptions.Item>
                  <Descriptions.Item label="引用关系">{preview.relation_count}</Descriptions.Item>
                </Descriptions>
                <WarningGroups warnings={preview.warnings} emptyText="文件结构良好" />
              </Card>
            )}
          </Space>
        </Card>
      )}

      {error && <Alert type="error" showIcon message={error} style={{ fontSize: 12 }} />}
    </Space>
  )

  const resultContent = (
    <>
      {result ? (
        <Space direction="vertical" size={12} style={{ width: '100%' }}>
          {/* 汇总指标 */}
          <Card size="small" className="result-summary-card">
            <div className="result-summary-header">
              <Text strong style={{ fontSize: 15 }}>{result.title}</Text>
            </div>
            <Row gutter={[12, 12]} style={{ marginTop: 10 }}>
              {result.summary.map((metric) => (
                <Col xs={12} sm={8} lg={6} key={metric.label}>
                  <Statistic
                    title={<span style={{ fontSize: 12 }}>{metric.label}</span>}
                    value={metric.value}
                    valueStyle={{ fontSize: 20, fontWeight: 600 }}
                  />
                  {metric.hint && <Text type="secondary" style={{ fontSize: 11 }}>{metric.hint}</Text>}
                </Col>
              ))}
            </Row>
          </Card>

          {/* 结果 Tabs */}
          <Card size="small" className="result-tabs-card">
            <Tabs
              size="small"
              items={[
                {
                  key: 'units',
                  label: scene === 'erp' ? '推荐角色' : '推荐宽表',
                  children: <UnitsTable units={result.units} scene={scene} sqlUnitGroups={result.sql_unit_groups} />,
                },
                {
                  key: 'assignments',
                  label: scene === 'erp' ? '用户分配' : '需求映射',
                  children: <AssignmentsTable assignments={result.assignments} />,
                },
                {
                  key: 'insights',
                  label: '结论与风险',
                  children: (
                    <Row gutter={[12, 12]}>
                      <Col xs={24} lg={12}>
                        <Card size="small" title="推荐结论">
                          <List
                            size="small"
                            dataSource={result.insights}
                            renderItem={(item) => <List.Item>{item}</List.Item>}
                          />
                        </Card>
                      </Col>
                      <Col xs={24} lg={12}>
                        <Card size="small" title="风险与后续建议">
                          <WarningGroups warnings={result.warnings} emptyText="当前无额外风险提示" />
                        </Card>
                      </Col>
                    </Row>
                  ),
                },
                ...(scene === 'erp' && result.erp_constraint_report
                  ? [{ key: 'constraints', label: '约束检查', children: <ConstraintReportView report={result.erp_constraint_report} /> }]
                  : []),
                ...(scene === 'erp' && result.erp_role_diff
                  ? [{ key: 'role-diff', label: '现状角色差异', children: <RoleDiffView report={result.erp_role_diff} /> }]
                  : []),
                ...(result.graph && result.graph.nodes.length > 0
                  ? [{
                      key: 'graph',
                      label: '关系图',
                      children: (
                        <GraphView
                          scene={scene}
                          data={result.graph as { nodes: Array<{ id: string; label: string; node_type: string; [key: string]: unknown }>; edges: Array<{ id: string; source: string; target: string; edge_type: string; label?: string; [key: string]: unknown }> }}
                        />
                      ),
                    }]
                  : []),
              ]}
            />
          </Card>
        </Space>
      ) : (
        <div className="result-empty">
          <Text type="secondary">请先在左侧选择场景或上传文件，结果将展示在此处。</Text>
        </div>
      )}
    </>
  )

  return (
    <Layout className="app-shell">
      <Layout.Header className="app-header">
        <div className="header-inner">
          <Title level={4} className="header-title">SetMiner</Title>
          <Text className="header-subtitle">ERP 角色权限优化 · SQL 宽表设计统一分析系统</Text>
        </div>
      </Layout.Header>
      <Layout>
        <Layout.Sider width={300} className="app-sider" theme="light">
          <div className="sider-scroll">{siderContent}</div>
        </Layout.Sider>
        <Layout.Content className="app-content">
          {resultContent}
        </Layout.Content>
      </Layout>
    </Layout>
  )
}

export default App

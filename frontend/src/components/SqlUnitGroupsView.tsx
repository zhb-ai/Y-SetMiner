import { useMemo } from 'react'
import { Collapse, Descriptions, Space, Table, Tag, Tooltip, Typography } from 'antd'
import type { TableColumnsType } from 'antd'
import { InfoCircleOutlined } from '@ant-design/icons'

import type { SolutionUnit, SqlUnitGroup } from '../types/api'
import { PlainTagsCell, TagsCell } from './unitTableShared'

const { Text } = Typography

interface SqlUnitGroupsViewProps {
  groups: SqlUnitGroup[]
}

function splitExtensionUnitName(name: string) {
  const match = name.match(/^(.*?扩展宽表)(\(.+\))$/)
  if (!match) {
    return { mainName: name, suffix: '' }
  }
  return {
    mainName: match[1].trim(),
    suffix: match[2].trim(),
  }
}

function groupFieldsBySource(names: string[], sources: string[]) {
  const grouped = new Map<string, string[]>()
  names.forEach((name, idx) => {
    const source = sources[idx] || 'unknown'
    const existing = grouped.get(source) ?? []
    existing.push(name)
    grouped.set(source, existing)
  })
  return Array.from(grouped.entries())
}

function SourceGroupedFields({
  names,
  sources,
  hits,
  supportCount,
}: {
  names: string[]
  sources: string[]
  hits?: number[]
  supportCount?: number | null
}) {
  const groups = groupFieldsBySource(names, sources)
  if (groups.length === 0) {
    return <Text type="secondary">无</Text>
  }

  return (
    <Space direction="vertical" size={8} style={{ width: '100%' }}>
      {groups.map(([source, fieldNames]) => (
        <div
          key={`${source}-${fieldNames.join('|')}`}
          style={{
            display: 'flex',
            alignItems: 'flex-start',
            gap: 8,
            flexWrap: 'wrap',
            padding: '6px 8px',
            background: '#fafafa',
            border: '1px solid #f0f0f0',
            borderRadius: 8,
          }}
        >
          <Tag color="geekblue" style={{ margin: 0, fontSize: 12 }}>
            {source}
          </Tag>
          <div style={{ flex: 1, minWidth: 220 }}>
            <TagsCell
              items={fieldNames.map((name) => {
                const nameIndex = names.findIndex((item, idx) => item === name && sources[idx] === source)
                const hit = hits?.[nameIndex]
                const label = hit && supportCount ? `${name}(${hit}/${supportCount})` : name
                return { name: label, expr: '' }
              })}
            />
          </div>
        </div>
      ))}
    </Space>
  )
}

function buildExtensionColumns(): TableColumnsType<SolutionUnit> {
  return [
    {
      title: '扩展宽表',
      dataIndex: 'name',
      key: 'name',
      width: 320,
      render: (value: string, record: SolutionUnit) => {
        const { mainName, suffix } = splitExtensionUnitName(value)
        return (
        <Space direction="vertical" size={2}>
          <Text strong style={{ fontSize: 12, lineHeight: 1.5 }}>{mainName}</Text>
          {suffix && (
            <Text
              type="secondary"
              style={{
                fontSize: 11,
                lineHeight: 1.5,
                whiteSpace: 'normal',
                wordBreak: 'break-all',
              }}
            >
              {suffix}
            </Text>
          )}
          <Space size={4} wrap>
            <Tag color="blue">{record.unit_level === 'extension' ? '扩展' : '独立'}</Tag>
            {record.covered_entity_names.length > 0 && <Tag>{`${record.covered_entity_names.length} 个 SQL`}</Tag>}
          </Space>
        </Space>
        )
      },
    },
    {
      title: '新增来源',
      key: 'extra_sources',
      width: 220,
      render: (_: unknown, record: SolutionUnit) => (
        record.extra_source_tables.length
          ? <PlainTagsCell items={record.extra_source_tables} maxVisible={4} containerWidth={200} tagMaxWidth={180} />
          : <Text type="secondary">无</Text>
      ),
    },
    {
      title: '新增字段',
      key: 'extra_items',
      width: 420,
      render: (_: unknown, record: SolutionUnit) => (
        record.extra_item_names.length
          ? <SourceGroupedFields names={record.extra_item_names} sources={record.extra_item_sources} />
          : <Text type="secondary">无</Text>
      ),
    },
    {
      title: '覆盖对象',
      key: 'covered_entities',
      width: 280,
      render: (_: unknown, record: SolutionUnit) => (
        <PlainTagsCell items={record.covered_entity_names} maxVisible={6} containerWidth={260} tagMaxWidth={220} />
      ),
    },
    {
      title: '得分',
      dataIndex: 'score',
      key: 'score',
      width: 80,
      align: 'center',
    },
  ]
}

function BaseUnitSummary({ unit, extensionCount }: { unit: SolutionUnit; extensionCount: number }) {
  return (
    <Descriptions
      size="small"
      bordered
      column={1}
      styles={{ label: { width: 110, fontWeight: 600 } }}
    >
      <Descriptions.Item label="基础宽表">
        <Space direction="vertical" size={6} style={{ width: '100%' }}>
          <Space size={6} wrap>
            <Text strong>{unit.name}</Text>
            <Tag color="gold">基础</Tag>
            <Tag>{`${unit.covered_entity_names.length} 个 SQL`}</Tag>
            <Tag>{`${extensionCount} 个扩展`}</Tag>
          </Space>
          <Text type="secondary" style={{ fontSize: 12 }}>{unit.rationale}</Text>
        </Space>
      </Descriptions.Item>
      <Descriptions.Item label="基础来源">
        {unit.sources.length
          ? <PlainTagsCell items={unit.sources} maxVisible={6} containerWidth={520} tagMaxWidth={220} />
          : <Text type="secondary">无</Text>}
      </Descriptions.Item>
      <Descriptions.Item label="基础字段">
        <SourceGroupedFields names={unit.item_display_names} sources={unit.item_sources} />
      </Descriptions.Item>
      <Descriptions.Item
        label={(
          <Space size={4}>
            <span>建议字段</span>
            <Tooltip
              title={`未达到基础字段阈值 ${unit.base_field_min_hits ?? '-'} 次，但达到建议字段阈值 ${unit.suggested_field_min_hits ?? '-'} 次。`}
            >
              <InfoCircleOutlined style={{ fontSize: 12, color: '#8c8c8c', cursor: 'pointer' }} />
            </Tooltip>
          </Space>
        )}
      >
        {unit.suggested_item_names.length
          ? (
            <SourceGroupedFields
              names={unit.suggested_item_names}
              sources={unit.suggested_item_sources}
              hits={unit.suggested_item_hits}
              supportCount={unit.support_unit_count}
            />
          )
          : <Text type="secondary">无</Text>}
      </Descriptions.Item>
    </Descriptions>
  )
}

export function SqlUnitGroupsView({ groups }: SqlUnitGroupsViewProps) {
  const extensionColumns = useMemo(() => buildExtensionColumns(), [])

  const panelItems = useMemo(
    () => groups.map((group, index) => {
      const panelKey = `${group.key}__${index}`
      return {
        key: panelKey,
        label: (
          <Space size={8} wrap>
            <Text strong>{group.group_name}</Text>
            <Tag color={group.base_unit.unit_level === 'standalone' ? 'default' : 'gold'}>
              {group.base_unit.unit_level === 'standalone' ? '独立宽表' : '基础宽表组'}
            </Tag>
            <Text type="secondary" style={{ fontSize: 12 }}>
              {group.base_unit.unit_level === 'standalone'
                ? `${group.base_unit.covered_entity_names.length} 个 SQL`
                : `${1 + group.units.length} 层结果`}
            </Text>
          </Space>
        ),
        children: group.base_unit.unit_level === 'standalone'
          ? (
            <Table
              rowKey="id"
              pagination={false}
              size="small"
              scroll={{ x: 'max-content' }}
              dataSource={[group.base_unit]}
              columns={extensionColumns}
            />
          )
          : (
            <Space direction="vertical" size={12} style={{ width: '100%' }}>
              <BaseUnitSummary unit={group.base_unit} extensionCount={group.units.length} />
              <Table
                rowKey="id"
                pagination={false}
                size="small"
                scroll={{ x: 'max-content' }}
                dataSource={group.units}
                columns={extensionColumns}
              />
            </Space>
          ),
      }
    }),
    [extensionColumns, groups],
  )

  const defaultKeys = useMemo(
    () => panelItems.map((item) => item.key),
    [panelItems],
  )

  return (
    <Collapse
      defaultActiveKey={defaultKeys}
      items={panelItems}
    />
  )
}

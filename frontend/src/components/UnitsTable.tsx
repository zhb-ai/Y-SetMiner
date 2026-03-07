import { useMemo, useState } from 'react'
import { Collapse, Table, Tag, Tooltip, Typography } from 'antd'
import { CodeOutlined } from '@ant-design/icons'

import type { SolutionUnit } from '../types/api'

const { Text } = Typography

const TAGS_COLLAPSED_MAX = 6
const ENTITY_TAGS_COLLAPSED_MAX = 8

interface TagItem {
  name: string
  expr: string
}

interface TagsCellProps {
  items: TagItem[]
}

interface PlainTagsCellProps {
  items: string[]
  maxVisible?: number
  containerWidth?: number
  tagMaxWidth?: number
}

function ExprTooltipContent({ expr }: { expr: string }) {
  return (
    <div style={{ maxWidth: 420, fontFamily: 'monospace', fontSize: 12, lineHeight: 1.7, whiteSpace: 'pre-wrap', wordBreak: 'break-all' }}>
      {expr}
    </div>
  )
}

function TagsCell({ items }: TagsCellProps) {
  const [expanded, setExpanded] = useState(false)
  const visible = expanded ? items : items.slice(0, TAGS_COLLAPSED_MAX)
  const extra = items.length - TAGS_COLLAPSED_MAX

  return (
    <div style={{ maxWidth: 340 }}>
      {visible.map((item, idx) => {
        const hasExpr = !!item.expr
        const tag = (
          <Tag
            key={`${item.name}-${idx}`}
            color={hasExpr ? 'purple' : undefined}
            icon={hasExpr ? <CodeOutlined /> : undefined}
            style={{
              maxWidth: hasExpr ? 180 : 160,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
              marginBottom: 2,
              display: 'inline-flex',
              alignItems: 'center',
              verticalAlign: 'middle',
              cursor: hasExpr ? 'help' : 'default',
            }}
          >
            {item.name}
          </Tag>
        )

        if (hasExpr) {
          return (
            <Tooltip
              key={`${item.name}-${idx}`}
              title={<ExprTooltipContent expr={item.expr} />}
              placement="topLeft"
              overlayStyle={{ maxWidth: 460 }}
              color="#1d1d2e"
            >
              {tag}
            </Tooltip>
          )
        }

        // 普通列名太长时也 Tooltip
        if (item.name.length > 22) {
          return (
            <Tooltip key={`${item.name}-${idx}`} title={item.name}>
              {tag}
            </Tooltip>
          )
        }

        return tag
      })}
      {!expanded && extra > 0 && (
        <Tag
          color="blue"
          style={{ cursor: 'pointer', marginBottom: 2 }}
          onClick={() => setExpanded(true)}
        >
          +{extra} 更多
        </Tag>
      )}
      {expanded && items.length > TAGS_COLLAPSED_MAX && (
        <Tag
          color="default"
          style={{ cursor: 'pointer', marginBottom: 2 }}
          onClick={() => setExpanded(false)}
        >
          收起
        </Tag>
      )}
    </div>
  )
}

function PlainTagsCell({
  items,
  maxVisible = ENTITY_TAGS_COLLAPSED_MAX,
  containerWidth = 420,
  tagMaxWidth = 220,
}: PlainTagsCellProps) {
  const [expanded, setExpanded] = useState(false)
  const visible = expanded ? items : items.slice(0, maxVisible)
  const extra = items.length - maxVisible

  return (
    <div style={{ maxWidth: containerWidth }}>
      {visible.map((item) => (
        <Tooltip key={item} title={item.length > 20 ? item : undefined}>
          <Tag
            style={{
              maxWidth: tagMaxWidth,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
              marginBottom: 2,
              display: 'inline-block',
              verticalAlign: 'middle',
            }}
          >
            {item}
          </Tag>
        </Tooltip>
      ))}
      {!expanded && extra > 0 && (
        <Tag
          color="blue"
          style={{ cursor: 'pointer', marginBottom: 2 }}
          onClick={() => setExpanded(true)}
        >
          +{extra} 更多
        </Tag>
      )}
      {expanded && items.length > maxVisible && (
        <Tag
          color="default"
          style={{ cursor: 'pointer', marginBottom: 2 }}
          onClick={() => setExpanded(false)}
        >
          收起
        </Tag>
      )}
    </div>
  )
}

interface UnitsTableProps {
  units: SolutionUnit[]
  scene: 'erp' | 'sql'
}

interface GroupedUnits {
  key: string
  groupName: string
  units: SolutionUnit[]
}

function splitUnitNameForSort(name: string) {
  const trimmed = name.trim()
  const match = trimmed.match(/^(.*?)(\d+)$/)
  if (!match) {
    return {
      baseName: trimmed,
      orderNo: Number.POSITIVE_INFINITY,
    }
  }

  return {
    baseName: match[1].trim(),
    orderNo: Number(match[2]),
  }
}

export function UnitsTable({ units, scene }: UnitsTableProps) {
  const itemTerm = scene === 'erp' ? '权限' : '字段'
  const sortedUnits = useMemo(() => {
    return [...units].sort((left, right) => {
      const leftSort = splitUnitNameForSort(left.name)
      const rightSort = splitUnitNameForSort(right.name)

      const baseCompare = leftSort.baseName.localeCompare(rightSort.baseName, 'zh-CN')
      if (baseCompare !== 0) {
        return baseCompare
      }

      if (leftSort.orderNo !== rightSort.orderNo) {
        return leftSort.orderNo - rightSort.orderNo
      }

      return left.name.localeCompare(right.name, 'zh-CN')
    })
  }, [units])

  const groupedUnits = useMemo<GroupedUnits[]>(() => {
    const groups = new Map<string, SolutionUnit[]>()
    for (const unit of sortedUnits) {
      const { baseName } = splitUnitNameForSort(unit.name)
      const existing = groups.get(baseName) ?? []
      existing.push(unit)
      groups.set(baseName, existing)
    }

    return Array.from(groups.entries()).map(([groupName, groupRows]) => ({
      key: groupName,
      groupName,
      units: groupRows,
    }))
  }, [sortedUnits])

  const columns = useMemo(() => [
    {
      title: '名称',
      dataIndex: 'name',
      key: 'name',
      width: 160,
      fixed: 'left' as const,
      ellipsis: { showTitle: false },
      render: (val: string) => (
        <Tooltip title={val}>
          <Text strong style={{ fontSize: 12 }}>{val}</Text>
        </Tooltip>
      ),
    },
    {
      title: itemTerm,
      key: 'items',
      width: 380,
      render: (_: unknown, record: SolutionUnit) => {
        const names = record.item_names ?? []
        const displayNames = record.item_display_names?.length ? record.item_display_names : names
        const exprs = record.item_exprs ?? []
        const tagItems: TagItem[] = names.map((name, i) => ({
          name: displayNames[i] ?? name,
          expr: exprs[i] ?? '',
        }))
        return <TagsCell items={tagItems} />
      },
    },
    {
      title: '覆盖对象',
      key: 'entities',
      width: 320,
      render: (_: unknown, record: SolutionUnit) => (
        <PlainTagsCell
          items={record.covered_entity_names}
          maxVisible={8}
          containerWidth={300}
          tagMaxWidth={260}
        />
      ),
    },
    {
      title: '来源',
      key: 'sources',
      width: 220,
      render: (_: unknown, record: SolutionUnit) =>
        record.sources.length
          ? (
            <PlainTagsCell
              items={record.sources}
              maxVisible={4}
              containerWidth={200}
              tagMaxWidth={180}
            />
          )
          : '-',
    },
    {
      title: '得分',
      dataIndex: 'score',
      key: 'score',
      width: 60,
      align: 'center' as const,
    },
    {
      title: '推荐理由',
      dataIndex: 'rationale',
      key: 'rationale',
      width: 220,
      ellipsis: { showTitle: false },
      render: (val: string) => (
        <Tooltip title={val}>
          <span style={{ fontSize: 12 }}>{val}</span>
        </Tooltip>
      ),
    },
  ], [itemTerm])

  if (scene === 'sql') {
    return (
      <Collapse
        defaultActiveKey={groupedUnits.map((group) => group.key)}
        items={groupedUnits.map((group) => ({
          key: group.key,
          label: (
            <span style={{ fontSize: 13, fontWeight: 600 }}>
              {group.groupName}
              <span style={{ marginLeft: 8, color: '#8c8c8c', fontWeight: 400 }}>
                {group.units.length} 张宽表
              </span>
            </span>
          ),
          children: (
            <Table
              rowKey="id"
              dataSource={group.units}
              pagination={false}
              scroll={{ x: 'max-content' }}
              size="small"
              columns={columns}
            />
          ),
        }))}
      />
    )
  }

  return (
    <Table
      rowKey="id"
      dataSource={sortedUnits}
      pagination={false}
      scroll={{ x: 'max-content' }}
      size="small"
      columns={columns}
    />
  )
}

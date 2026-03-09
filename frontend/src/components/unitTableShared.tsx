import { useState } from 'react'
import { Tag, Tooltip, Typography } from 'antd'
import { CodeOutlined } from '@ant-design/icons'
import type { TableColumnsType } from 'antd'

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
  containerWidth?: number | string
  tagMaxWidth?: number | string
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

export function TagsCell({
  items,
  containerWidth = 340,
  tagMaxWidth = 160,
}: TagsCellProps) {
  const [expanded, setExpanded] = useState(false)
  const visible = expanded ? items : items.slice(0, TAGS_COLLAPSED_MAX)
  const extra = items.length - TAGS_COLLAPSED_MAX

  return (
    <div style={{ maxWidth: containerWidth }}>
      {visible.map((item, idx) => {
        const hasExpr = !!item.expr
        const resolvedTagMaxWidth = typeof tagMaxWidth === 'number'
          ? (hasExpr ? Math.max(tagMaxWidth + 20, 180) : tagMaxWidth)
          : tagMaxWidth
        const tag = (
          <Tag
            key={`${item.name}-${idx}`}
            color={hasExpr ? 'purple' : undefined}
            icon={hasExpr ? <CodeOutlined /> : undefined}
            style={{
              maxWidth: resolvedTagMaxWidth,
              overflow: resolvedTagMaxWidth ? 'hidden' : 'visible',
              textOverflow: resolvedTagMaxWidth ? 'ellipsis' : 'clip',
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
        <Tag color="blue" style={{ cursor: 'pointer', marginBottom: 2 }} onClick={() => setExpanded(true)}>
          +{extra} 更多
        </Tag>
      )}
      {expanded && items.length > TAGS_COLLAPSED_MAX && (
        <Tag color="default" style={{ cursor: 'pointer', marginBottom: 2 }} onClick={() => setExpanded(false)}>
          收起
        </Tag>
      )}
    </div>
  )
}

export function PlainTagsCell({
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
        <Tag color="blue" style={{ cursor: 'pointer', marginBottom: 2 }} onClick={() => setExpanded(true)}>
          +{extra} 更多
        </Tag>
      )}
      {expanded && items.length > maxVisible && (
        <Tag color="default" style={{ cursor: 'pointer', marginBottom: 2 }} onClick={() => setExpanded(false)}>
          收起
        </Tag>
      )}
    </div>
  )
}

export function splitUnitNameForSort(name: string) {
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

export function buildUnitColumns(itemTerm: string): TableColumnsType<SolutionUnit> {
  return [
    {
      title: '名称',
      dataIndex: 'name',
      key: 'name',
      width: 160,
      fixed: 'left',
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
      render: (_: unknown, record: SolutionUnit) => (
        record.sources.length
          ? (
            <PlainTagsCell
              items={record.sources}
              maxVisible={4}
              containerWidth={200}
              tagMaxWidth={180}
            />
          )
          : '-'
      ),
    },
    {
      title: '得分',
      dataIndex: 'score',
      key: 'score',
      width: 60,
      align: 'center',
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
  ]
}

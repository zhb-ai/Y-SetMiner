import { useState } from 'react'
import { Table, Tag, Tooltip, Typography } from 'antd'
import { CodeOutlined } from '@ant-design/icons'

import type { SolutionUnit } from '../types/api'

const { Text } = Typography

const TAGS_COLLAPSED_MAX = 6

interface TagItem {
  name: string
  expr: string
}

interface TagsCellProps {
  items: TagItem[]
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

interface UnitsTableProps {
  units: SolutionUnit[]
  scene: 'erp' | 'sql'
}

export function UnitsTable({ units, scene }: UnitsTableProps) {
  const itemTerm = scene === 'erp' ? '权限' : '字段'
  return (
    <Table
      rowKey="id"
      dataSource={units}
      pagination={false}
      scroll={{ x: 'max-content' }}
      size="small"
      columns={[
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
          render: (_, record) => {
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
          width: 220,
          render: (_, record) => (
            <div style={{ maxWidth: 200 }}>
              {record.covered_entity_names.map((name) => (
                <Tooltip key={name} title={name.length > 20 ? name : undefined}>
                  <Tag
                    style={{
                      maxWidth: 190,
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                      marginBottom: 2,
                      display: 'inline-block',
                      verticalAlign: 'middle',
                    }}
                  >
                    {name}
                  </Tag>
                </Tooltip>
              ))}
            </div>
          ),
        },
        {
          title: '来源',
          key: 'sources',
          width: 160,
          render: (_, record) =>
            record.sources.length
              ? record.sources.map((source) => (
                  <Tooltip key={source} title={source.length > 18 ? source : undefined}>
                    <Tag
                      style={{
                        maxWidth: 140,
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                        marginBottom: 2,
                        display: 'inline-block',
                        verticalAlign: 'middle',
                      }}
                    >
                      {source}
                    </Tag>
                  </Tooltip>
                ))
              : '-',
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
      ]}
    />
  )
}

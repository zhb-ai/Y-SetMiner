import { useMemo } from 'react'
import { Collapse, Table } from 'antd'

import type { SolutionUnit, SqlUnitGroup } from '../types/api'
import { SqlUnitGroupsView } from './SqlUnitGroupsView'
import { buildUnitColumns, splitUnitNameForSort } from './unitTableShared'

interface UnitsTableProps {
  units: SolutionUnit[]
  scene: 'erp' | 'sql'
  sqlUnitGroups?: SqlUnitGroup[] | null
}

interface GroupedUnits {
  key: string
  groupName: string
  units: SolutionUnit[]
}

export function UnitsTable({ units, scene, sqlUnitGroups }: UnitsTableProps) {
  const itemTerm = scene === 'erp' ? '权限' : '字段'

  const sortedUnits = useMemo(() => {
    return [...units].sort((left, right) => {
      const leftSort = splitUnitNameForSort(left.name)
      const rightSort = splitUnitNameForSort(right.name)
      const baseCompare = leftSort.baseName.localeCompare(rightSort.baseName, 'zh-CN')
      if (baseCompare !== 0) return baseCompare
      if (leftSort.orderNo !== rightSort.orderNo) return leftSort.orderNo - rightSort.orderNo
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

  const columns = useMemo(() => buildUnitColumns(itemTerm), [itemTerm])

  if (scene === 'sql' && sqlUnitGroups?.length) {
    return <SqlUnitGroupsView groups={sqlUnitGroups} />
  }

  if (scene === 'sql') {
    return (
      <Collapse
        defaultActiveKey={groupedUnits.map((group) => group.key)}
        items={groupedUnits.map((group) => ({
          key: group.key,
          label: `${group.groupName} (${group.units.length} 张宽表)`,
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

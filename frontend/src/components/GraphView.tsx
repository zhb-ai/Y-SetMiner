import { Graph as G6Graph } from '@antv/g6';
import type { GraphOptions, IElementEvent } from '@antv/g6';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Button, Space, Tag, Typography } from 'antd';
import { CompressOutlined, ExpandOutlined, ReloadOutlined } from '@ant-design/icons';

const { Text } = Typography;

interface GraphNode {
  id: string;
  label: string;
  node_type: string;
  [key: string]: unknown;
}

interface GraphEdge {
  id: string;
  source: string;
  target: string;
  edge_type: string;
  label?: string;
  [key: string]: unknown;
}

interface GraphData {
  nodes: GraphNode[];
  edges: GraphEdge[];
}

interface GraphViewProps {
  scene: 'sql' | 'erp';
  data: GraphData;
}

// ─── 节点颜色映射 ─────────────────────────────────────────────────────────────
const NODE_COLORS: Record<string, { fill: string; stroke: string; labelColor: string }> = {
  table:       { fill: '#e6f4ff', stroke: '#1677ff', labelColor: '#1677ff' },
  wide_table:  { fill: '#fff7e6', stroke: '#fa8c16', labelColor: '#d46b08' },
  sql_file:    { fill: '#f6ffed', stroke: '#52c41a', labelColor: '#389e0d' },
  user:        { fill: '#e6f4ff', stroke: '#1677ff', labelColor: '#1677ff' },
  role:        { fill: '#fff7e6', stroke: '#fa8c16', labelColor: '#d46b08' },
  permission:  { fill: '#f9f0ff', stroke: '#722ed1', labelColor: '#531dab' },
};

// ─── 边颜色映射 ───────────────────────────────────────────────────────────────
const EDGE_COLORS: Record<string, string> = {
  join:             '#1677ff',
  field_belongs:    '#fa8c16',
  covers:           '#52c41a',
  user_role:        '#1677ff',
  role_permission:  '#722ed1',
};

// ─── 节点层级（用于 dagre rank 分组，保证倒金字塔方向）─────────────────────────
// SQL：物理表(0) → 宽表(1) → SQL文件(2)
// ERP：用户(0) → 角色(1) → 权限(2)
const NODE_RANK: Record<string, number> = {
  table: 0,
  wide_table: 1,
  sql_file: 2,
  user: 0,
  role: 1,
  permission: 2,
};

const LAYER_MAX_PER_ROW: Record<number, number> = {
  0: 5,
  1: 4,
  2: 5,
};

const LAYER_SUBROW_GAP = 88;

function splitLayerRows(total: number, layer: number) {
  const maxPerRow = LAYER_MAX_PER_ROW[layer] ?? 5;
  const rowCount = Math.max(Math.ceil(total / maxPerRow), 1);
  return { maxPerRow, rowCount };
}

function getLayeredPosition(
  index: number,
  total: number,
  layer: number,
  width: number,
  height: number,
): { x: number; y: number } {
  const safeTotal = Math.max(total, 1);
  const { maxPerRow, rowCount } = splitLayerRows(safeTotal, layer);
  const rowIndex = Math.floor(index / maxPerRow);
  const colIndex = index % maxPerRow;
  const nodesInThisRow =
    rowIndex === rowCount - 1 ? safeTotal - rowIndex * maxPerRow || maxPerRow : maxPerRow;
  const horizontalPadding = 110;
  const layerTop = 90;
  const layerGap = Math.max((height - 220) / 2, 170);
  const centeredRowOffset = rowCount > 1 ? (rowIndex - (rowCount - 1) / 2) * LAYER_SUBROW_GAP : 0;

  if (nodesInThisRow === 1) {
    return {
      x: width / 2,
      y: layerTop + layer * layerGap + centeredRowOffset,
    };
  }

  const usableWidth = Math.max(width - horizontalPadding * 2, 320);
  const step = usableWidth / (nodesInThisRow - 1);
  const rowWidth = step * (nodesInThisRow - 1);
  const rowStartX = (width - rowWidth) / 2;
  const x = rowStartX + colIndex * step;
  const y = layerTop + layer * layerGap + centeredRowOffset;

  return { x, y };
}

function estimateCanvasHeight(nodes: GraphNode[]) {
  const layerCounts = new Map<number, number>();
  nodes.forEach((node) => {
    const layer = NODE_RANK[node.node_type] ?? 0;
    layerCounts.set(layer, (layerCounts.get(layer) ?? 0) + 1);
  });

  const extraRows = Array.from(layerCounts.entries()).reduce((sum, [layer, count]) => {
    const { rowCount } = splitLayerRows(count, layer);
    return sum + Math.max(rowCount - 1, 0);
  }, 0);

  return Math.max(620 + extraRows * 70, 620);
}

function buildLayeredNodeStyles(
  nodes: GraphNode[],
  containerWidth: number,
  canvasHeight: number,
) {
  const layers = new Map<number, GraphNode[]>();
  nodes.forEach((node) => {
    const layer = NODE_RANK[node.node_type] ?? 0;
    const list = layers.get(layer) ?? [];
    list.push(node);
    layers.set(layer, list);
  });

  return nodes.map((n) => {
    const style = getNodeStyle(n);
    const isLarge = n.node_type === 'wide_table' || n.node_type === 'role';
    const layer = NODE_RANK[n.node_type] ?? 0;
    const layerNodes = layers.get(layer) ?? [n];
    const index = layerNodes.findIndex((item) => item.id === n.id);
    const pos = getLayeredPosition(index, layerNodes.length, layer, containerWidth, canvasHeight);

    return {
      id: n.id,
      data: { ...n, _rank: layer },
      style: {
        ...style,
        x: pos.x,
        y: pos.y,
        size: isLarge ? 52 : 38,
        labelText: n.label.length > 16 ? n.label.slice(0, 14) + '…' : n.label,
        labelPlacement: 'bottom' as const,
        labelOffsetY: 6,
        cursor: 'pointer' as const,
      },
    };
  });
}

// ─── 警告节点特殊样式 ─────────────────────────────────────────────────────────
function getNodeStyle(node: GraphNode) {
  const base = NODE_COLORS[node.node_type] ?? { fill: '#f5f5f5', stroke: '#d9d9d9', labelColor: '#333' };
  const hasWarn = node.has_join_warning || node.has_granularity_warning;
  return {
    fill: hasWarn ? '#fff1f0' : base.fill,
    stroke: hasWarn ? '#ff4d4f' : base.stroke,
    lineWidth: hasWarn ? 2.5 : 1.5,
    labelFill: base.labelColor,
    labelFontSize: 12,
    labelFontWeight: node.node_type === 'wide_table' || node.node_type === 'role' ? 600 : 400,
  };
}

function buildG6Options(data: GraphData, containerWidth: number, canvasHeight: number): GraphOptions {
  const g6Nodes = buildLayeredNodeStyles(data.nodes, containerWidth, canvasHeight);

  const g6Edges = data.edges.map((e) => ({
    id: e.id,
    source: e.source,
    target: e.target,
    data: e,
    style: {
      stroke: EDGE_COLORS[e.edge_type] ?? '#999',
      lineWidth: 1.5,
      endArrow: true,
      endArrowSize: 7,
      // JOIN 边显示关联字段，其余边不显示标签（避免太杂）
      labelText: e.edge_type === 'join' ? (e.label ?? '') : '',
      labelFontSize: 10,
      labelFill: '#888',
      opacity: 0.85,
    },
  }));

  return {
    width: containerWidth,
    height: canvasHeight,
    data: { nodes: g6Nodes, edges: g6Edges },
    node: { type: 'circle' },
    edge: { type: 'cubic' },
    behaviors: [
      'drag-canvas',
      'zoom-canvas',
      'drag-element',
      { type: 'click-select', multiple: false },
      'hover-activate',
    ],
    plugins: [
      {
        type: 'tooltip',
        getContent: (_: Event, items: { data?: { data?: GraphNode } }[]) => {
          const item = items[0];
          if (!item?.data?.data) return '';
          const d = item.data.data as GraphNode;
          const lines: string[] = [`<b>${d.label}</b>`];
          if (d.node_type === 'wide_table') {
            lines.push(`字段数：${d.field_count}`);
            lines.push(`得分：${d.score}`);
            if (d.has_join_warning) lines.push(`⚠ JOIN 孤立警告`);
            if (d.has_granularity_warning) lines.push(`⚠ 粒度冲突警告`);
            if (d.join_warning_reason) lines.push(String(d.join_warning_reason));
            if (d.granularity_warning_reason) lines.push(String(d.granularity_warning_reason));
            if (d.rationale) lines.push(String(d.rationale));
          } else if (d.node_type === 'table') {
            lines.push(`字段数：${d.field_count}`);
          } else if (d.node_type === 'role') {
            lines.push(`权限数：${d.permission_count}`);
            lines.push(`得分：${d.score}`);
            if (d.rationale) lines.push(String(d.rationale));
          } else if (d.node_type === 'user') {
            if ((d.uncovered_count as number) > 0) {
              lines.push(`未覆盖权限数：${d.uncovered_count}`);
            }
          }
          return `<div style="padding:4px 8px;font-size:12px;line-height:1.6">${lines.join('<br/>')}</div>`;
        },
      },
    ],
    autoFit: 'view',
    theme: 'light',
  };
}

// ─── 图例 ─────────────────────────────────────────────────────────────────────
const SQL_LEGEND = [
  { type: 'table',      label: '物理表',  color: '#1677ff' },
  { type: 'wide_table', label: '推荐宽表', color: '#fa8c16' },
  { type: 'sql_file',   label: 'SQL文件',  color: '#52c41a' },
];
const ERP_LEGEND = [
  { type: 'user',       label: '用户',    color: '#1677ff' },
  { type: 'role',       label: '推荐角色', color: '#fa8c16' },
  { type: 'permission', label: '权限',    color: '#722ed1' },
];

// ─── 全屏容器样式（注入 <head>，只注入一次）─────────────────────────────────
const FULLSCREEN_STYLE_ID = 'graph-fullscreen-style';
function ensureFullscreenStyle() {
  if (document.getElementById(FULLSCREEN_STYLE_ID)) return;
  const style = document.createElement('style');
  style.id = FULLSCREEN_STYLE_ID;
  style.textContent = `
    .graph-fullscreen-wrap:fullscreen,
    .graph-fullscreen-wrap:-webkit-full-screen {
      background: #fff;
      display: flex;
      flex-direction: column;
      padding: 16px;
      box-sizing: border-box;
    }
    .graph-fullscreen-wrap:fullscreen .graph-canvas-inner,
    .graph-fullscreen-wrap:-webkit-full-screen .graph-canvas-inner {
      flex: 1;
      height: 0 !important;
    }
  `;
  document.head.appendChild(style);
}

export default function GraphView({ scene, data }: GraphViewProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);         // 画布外层（监听宽度）
  const fullscreenRef = useRef<HTMLDivElement>(null);   // 全屏目标容器
  const graphRef = useRef<G6Graph | undefined>(undefined);

  const [containerWidth, setContainerWidth] = useState(900);
  const [canvasHeight, setCanvasHeight] = useState(620);
  const [selectedNode, setSelectedNode] = useState<GraphNode | null>(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const naturalCanvasHeight = useMemo(() => estimateCanvasHeight(data.nodes), [data.nodes]);

  // 注入全屏样式
  useEffect(() => { ensureFullscreenStyle(); }, []);

  // 监听容器宽度变化
  useEffect(() => {
    if (!wrapRef.current) return;
    const ro = new ResizeObserver((entries) => {
      const rect = entries[0]?.contentRect;
      if (rect?.width > 200) setContainerWidth(rect.width);
    });
    ro.observe(wrapRef.current);
    return () => ro.disconnect();
  }, []);

  // 监听全屏状态变化（用于更新图标 & 画布高度）
  useEffect(() => {
    const handleChange = () => {
      const fs = !!document.fullscreenElement;
      setIsFullscreen(fs);
      // 全屏时撑满整个屏幕高度；普通状态按节点密度自动增高
      setCanvasHeight(fs ? Math.max(window.innerHeight - 120, naturalCanvasHeight) : naturalCanvasHeight);
    };
    document.addEventListener('fullscreenchange', handleChange);
    return () => document.removeEventListener('fullscreenchange', handleChange);
  }, [naturalCanvasHeight]);

  useEffect(() => {
    if (!isFullscreen) {
      setCanvasHeight(naturalCanvasHeight);
    }
  }, [isFullscreen, naturalCanvasHeight]);

  // 构建 G6 options
  const options = useMemo(
    () => buildG6Options(data, containerWidth, canvasHeight),
    [data, containerWidth, canvasHeight],
  );

  // 初始化 G6 实例（Strict Mode 安全）
  useEffect(() => {
    if (!containerRef.current) return;
    const graph = new G6Graph({ container: containerRef.current });
    graphRef.current = graph;
    return () => {
      graph.destroy();
      graphRef.current = undefined;
    };
  }, []);

  // 更新数据 & 渲染
  useEffect(() => {
    const graph = graphRef.current;
    if (!graph || graph.destroyed) return;
    graph.setOptions(options);
    graph
      .render()
      .then(() => {
        graph.on('node:click', (evt: IElementEvent) => {
          const nodeId: string = (evt.target as { id: string }).id;
          setSelectedNode(data.nodes.find((n) => n.id === nodeId) ?? null);
        });
        graph.on('canvas:click', () => setSelectedNode(null));
      })
      .catch(() => {});
  }, [options, data.nodes]);

  const handleFitView = useCallback(() => graphRef.current?.fitView(), []);
  const handleReset = useCallback(() => {
    setSelectedNode(null);
    graphRef.current?.fitView();
  }, []);

  // 全屏切换
  const handleFullscreen = useCallback(async () => {
    const el = fullscreenRef.current;
    if (!el) return;
    if (!document.fullscreenElement) {
      await el.requestFullscreen().catch(() => {});
    } else {
      await document.exitFullscreen().catch(() => {});
    }
  }, []);

  const legend = scene === 'sql' ? SQL_LEGEND : ERP_LEGEND;

  return (
    // 全屏目标容器
    <div
      ref={fullscreenRef}
      className="graph-fullscreen-wrap"
      style={{ display: 'flex', flexDirection: 'column', gap: 10 }}
    >
      {/* ── 工具栏 ── */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: 8,
        flexShrink: 0,
      }}>
        <Space wrap size={4}>
          {legend.map((item) => (
            <Tag key={item.type} color={item.color} style={{ borderRadius: 4, margin: 0, fontSize: 11 }}>
              {item.label}
            </Tag>
          ))}
          {scene === 'sql' && (
            <Tag color="error" style={{ borderRadius: 4, margin: 0, fontSize: 11 }}>⚠ 红框节点有警告</Tag>
          )}
        </Space>
        <Space size={4}>
          <Button size="small" style={{ fontSize: 11 }} icon={<ReloadOutlined />} onClick={handleReset}>重置</Button>
          <Button size="small" style={{ fontSize: 11 }} onClick={handleFitView}>自适应</Button>
          <Button
            size="small"
            style={{ fontSize: 11 }}
            type={isFullscreen ? 'primary' : 'default'}
            icon={isFullscreen ? <CompressOutlined /> : <ExpandOutlined />}
            onClick={handleFullscreen}
          >
            {isFullscreen ? '退出全屏' : '全屏'}
          </Button>
        </Space>
      </div>

      {/* ── 画布 ── */}
      <div
        ref={wrapRef}
        style={{
          border: '1px solid #e8e8e8',
          borderRadius: 8,
          background: '#fafbfc',
          overflow: 'hidden',
          position: 'relative',
          flex: isFullscreen ? 1 : 'none',
        }}
      >
        <div
          ref={containerRef}
          className="graph-canvas-inner"
          style={{ width: '100%', height: canvasHeight }}
        />
        <Text type="secondary" style={{
          position: 'absolute', bottom: 8, right: 12, fontSize: 11, pointerEvents: 'none',
        }}>
          拖拽移动 · 滚轮缩放 · 点击节点查看详情
        </Text>
      </div>

      {/* ── 节点详情面板 ── */}
      {selectedNode && (
        <div style={{
          padding: '10px 14px',
          background: '#fff',
          border: '1px solid #e8e8e8',
          borderRadius: 8,
          fontSize: 13,
          flexShrink: 0,
        }}>
          <Text strong style={{ fontSize: 14 }}>{selectedNode.label}</Text>
          <div style={{ marginTop: 6, display: 'flex', flexWrap: 'wrap', gap: '4px 16px', color: '#555' }}>
            {selectedNode.node_type === 'wide_table' && (<>
              <span>字段数：<b>{String(selectedNode.field_count)}</b></span>
              <span>得分：<b>{String(selectedNode.score)}</b></span>
              {selectedNode.sources && (selectedNode.sources as string[]).length > 0 && (
                <span>来源表：<b>{(selectedNode.sources as string[]).join('、')}</b></span>
              )}
              {selectedNode.has_join_warning && <Tag color="error">⚠ JOIN 孤立</Tag>}
              {selectedNode.has_granularity_warning && <Tag color="warning">⚠ 粒度冲突</Tag>}
              {selectedNode.join_warning_reason && (
                <div style={{ width: '100%', color: '#cf1322', marginTop: 4 }}>
                  原因：{String(selectedNode.join_warning_reason)}
                </div>
              )}
              {selectedNode.granularity_warning_reason && (
                <div style={{ width: '100%', color: '#d48806', marginTop: 4 }}>
                  原因：{String(selectedNode.granularity_warning_reason)}
                </div>
              )}
              {selectedNode.rationale && (
                <div style={{ width: '100%', color: '#888', marginTop: 4 }}>{String(selectedNode.rationale)}</div>
              )}
            </>)}
            {selectedNode.node_type === 'table' && (
              <span>字段数：<b>{String(selectedNode.field_count)}</b></span>
            )}
            {selectedNode.node_type === 'role' && (<>
              <span>权限数：<b>{String(selectedNode.permission_count)}</b></span>
              <span>得分：<b>{String(selectedNode.score)}</b></span>
              {selectedNode.rationale && (
                <div style={{ width: '100%', color: '#888', marginTop: 4 }}>{String(selectedNode.rationale)}</div>
              )}
            </>)}
            {selectedNode.node_type === 'user' && (selectedNode.uncovered_count as number) > 0 && (
              <Tag color="warning">未覆盖权限 {String(selectedNode.uncovered_count)} 个</Tag>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

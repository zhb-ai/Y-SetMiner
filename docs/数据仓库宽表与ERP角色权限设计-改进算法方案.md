# 数据仓库宽表与ERP角色权限设计——改进算法方案

> 本文档基于《数据仓库宽表与ERP角色权限设计算法方案》的分析与评审，提出更优的算法选型与实现路径。

---

## 一、原方案回顾与问题诊断

### 1.1 原方案核心思路

原方案将两个业务场景（数据仓库宽表设计、ERP角色权限设计）统一抽象为**带约束的集合覆盖与聚类问题**，推荐使用"频繁项集挖掘 + 聚类"组合算法。

### 1.2 原方案存在的关键问题

| # | 问题 | 影响 | 严重程度 |
|---|------|------|---------|
| 1 | **频繁项集复杂度为指数级** O(n×2^m)，字段数 m 上百时不可行 | 算法无法在合理时间内完成 | 🔴 高 |
| 2 | **缺乏统一优化目标函数**，三阶段各自优化方向不一致 | 最终结果非全局最优 | 🔴 高 |
| 3 | **频繁项集不直接回答"建几张表"**，需要大量二次加工 | 从输出到可用方案的 gap 大 | 🟡 中 |
| 4 | **硬聚类不支持重叠**，但用户/报表天然存在多对多关系 | 结果与业务实际不符 | 🟡 中 |
| 5 | **数据仓库特殊约束处理不足**（JOIN路径、数据粒度、更新频率） | 生成的宽表可能无法落地 | 🟡 中 |
| 6 | **缺少评估指标体系**，仅有覆盖率一个维度 | 无法衡量方案好坏 | 🟡 中 |
| 7 | **忽略了矩阵分解和数学规划类算法**，这才是此类问题的最优解法 | 错过了最直接有效的方案 | 🔴 高 |

---

## 二、问题本质再分析

### 2.1 更精确的数学建模

两个场景的本质是**布尔矩阵分解问题（Boolean Matrix Factorization）**：

```
给定：二值矩阵 M ∈ {0,1}^(n×m)
  - 数据仓库场景：M[i][j] = 1 表示报表 i 需要字段 j
  - ERP权限场景：M[i][j] = 1 表示用户 i 拥有权限 j

目标：找到两个二值矩阵 R 和 P，使得

  M ≈ R ⊗ P

  R ∈ {0,1}^(n×k)  —— 用户/报表 → 角色/宽表 的映射
  P ∈ {0,1}^(k×m)  —— 角色/宽表 → 权限/字段 的定义
  ⊗ 为布尔矩阵乘法（OR-AND）

  最小化 k（角色/宽表数量）
  约束：R ⊗ P 覆盖 M 中所有的 1
```

### 2.2 与原方案建模的对比

| 维度 | 原方案建模 | 改进建模 |
|------|-----------|---------|
| **问题类型** | 集合覆盖 + 聚类 | 布尔矩阵分解 |
| **优化目标** | 模糊（分阶段各自优化） | 清晰（最小化重构误差和分解秩 k） |
| **输出** | 需要二次加工 | 直接输出角色定义 + 用户映射 |
| **重叠支持** | 不支持（硬聚类） | 天然支持（一个用户可映射多个角色） |
| **约束集成** | 后处理添加约束 | 可嵌入优化模型 |

### 2.3 为什么矩阵分解是更自然的建模？

```
原始用户-权限矩阵 M:          分解后:

         p1 p2 p3 p4 p5               角色A  角色B          p1 p2 p3 p4 p5
用户1  [ 1  1  1  0  0 ]     用户1  [ 1      0   ]   角色A [ 1  1  1  0  0 ]
用户2  [ 1  1  1  0  0 ]  =  用户2  [ 1      0   ] × 角色B [ 0  0  0  1  1 ]
用户3  [ 0  0  0  1  1 ]     用户3  [ 0      1   ]
用户4  [ 1  1  1  1  1 ]     用户4  [ 1      1   ]
                                  R (n×k)              P (k×m)

解读：
- 角色A = {p1, p2, p3}
- 角色B = {p4, p5}
- 用户4 同时拥有角色A和角色B（天然支持重叠）
```

---

## 三、改进算法方案

### 3.1 推荐方案：三层架构

```
┌─────────────────────────────────────────────────────────────┐
│  第一层：核心分解算法（NMF/BMF）                              │
│  - 将用户-需求项矩阵分解为 用户-角色 × 角色-需求项              │
│  - 输出初始角色/宽表方案                                      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  第二层：约束优化（ILP 整数线性规划）                          │
│  - 加入业务硬约束（字段上限、权限冲突、JOIN 可达性等）           │
│  - 精确优化角色/宽表的数量和组成                                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  第三层：评估与调优                                           │
│  - 多维度评估方案质量                                         │
│  - 业务专家评审与迭代                                         │
│  - 增量更新机制                                               │
└─────────────────────────────────────────────────────────────┘
```

---

### 3.2 第一层：核心分解算法

#### 3.2.1 方案 A：非负矩阵分解（NMF）——入门首选

**核心思想**：将非负矩阵 M 分解为两个非负矩阵的乘积 M ≈ R × P，然后二值化。

**算法流程**：

```
输入：用户-需求项二值矩阵 M (n×m)，目标分解秩 k
输出：角色/宽表定义矩阵 P (k×m)，用户映射矩阵 R (n×k)

1. 初始化 R, P 为随机非负矩阵
2. 交替优化（乘法更新规则）：
   R ← R ⊙ (M × Pᵀ) / (R × P × Pᵀ)
   P ← P ⊙ (Rᵀ × M) / (Rᵀ × R × P)
3. 重复步骤 2 直到收敛
4. 二值化：
   P_binary[j][l] = 1  当 P[j][l] > threshold_p
   R_binary[i][j] = 1  当 R[i][j] > threshold_r
5. 验证覆盖率：检查 R_binary ⊗ P_binary 是否覆盖 M 中所有的 1
6. 若覆盖不足，增加 k 或调整阈值，回到步骤 1
```

**Python 实现**：

```python
import numpy as np
from sklearn.decomposition import NMF
from sklearn.metrics import precision_score, recall_score

class NMFRoleMiner:
    """基于NMF的角色/宽表挖掘器"""
    
    def __init__(self, max_roles=20, threshold_role=0.3, threshold_perm=0.5):
        self.max_roles = max_roles
        self.threshold_role = threshold_role  # 用户-角色映射阈值
        self.threshold_perm = threshold_perm  # 角色-权限映射阈值
    
    def fit(self, M):
        """
        M: np.ndarray, shape (n_users, n_permissions), 二值矩阵
        """
        best_k, best_score = 1, -1
        best_R, best_P = None, None
        
        # 自动搜索最优 k 值
        for k in range(2, self.max_roles + 1):
            model = NMF(n_components=k, init='nndsvd', max_iter=500, random_state=42)
            R = model.fit_transform(M)
            P = model.components_
            
            # 二值化
            R_bin = (R > self.threshold_role).astype(int)
            P_bin = (P > self.threshold_perm).astype(int)
            
            # 重构矩阵（布尔乘法）
            M_reconstructed = np.clip(R_bin @ P_bin, 0, 1)
            
            # 评估：覆盖率（召回率）和精确率
            coverage = recall_score(M.flatten(), M_reconstructed.flatten())
            precision = precision_score(M.flatten(), M_reconstructed.flatten(), 
                                       zero_division=1)
            
            # 综合评分：覆盖率优先，兼顾精确率和角色数量
            score = coverage * 0.5 + precision * 0.3 - (k / self.max_roles) * 0.2
            
            if coverage >= 0.95 and score > best_score:
                best_score = score
                best_k = k
                best_R = R_bin
                best_P = P_bin
        
        self.n_roles = best_k
        self.user_role_matrix = best_R   # 用户-角色映射
        self.role_perm_matrix = best_P   # 角色-权限定义
        
        return self
    
    def get_roles(self, perm_names=None):
        """获取角色定义"""
        roles = []
        for j in range(self.n_roles):
            perm_indices = np.where(self.role_perm_matrix[j] == 1)[0]
            role = {
                'role_id': j,
                'permission_indices': perm_indices.tolist(),
                'permission_names': [perm_names[idx] for idx in perm_indices] 
                                    if perm_names else None,
                'n_permissions': len(perm_indices),
                'n_users': int(self.user_role_matrix[:, j].sum()),
            }
            roles.append(role)
        return roles
    
    def get_user_mappings(self, user_names=None):
        """获取用户-角色映射"""
        mappings = {}
        for i in range(self.user_role_matrix.shape[0]):
            role_indices = np.where(self.user_role_matrix[i] == 1)[0]
            key = user_names[i] if user_names else f"user_{i}"
            mappings[key] = role_indices.tolist()
        return mappings
```

**优点**：
- sklearn 直接可用，开发成本最低
- 自动确定角色/宽表数量（通过搜索最优 k）
- 天然支持重叠（一个用户可属于多个角色）
- 结果直接可用，无需二次加工

**缺点**：
- NMF 处理的是实数矩阵，需要二值化，阈值选择影响结果
- 不保证精确覆盖，可能需要后处理补全

**复杂度**：`O(n × m × k × iter)`，线性可控

---

#### 3.2.2 方案 B：布尔矩阵分解（BMF）——理论最优

**核心思想**：直接在布尔域上分解，避免 NMF 的实数→布尔转换损失。

**算法流程**：

```
输入：二值矩阵 M (n×m)，目标秩 k
输出：R (n×k) 和 P (k×m)，均为二值矩阵

ASSO 算法：
1. 计算需求项之间的关联矩阵 A (m×m)
   A[j][l] = |{i : M[i][j]=1 ∧ M[i][l]=1}| / |{i : M[i][j]=1 ∨ M[i][l]=1}|
   （Jaccard 相似度）

2. 对关联矩阵 A 按阈值 τ 二值化得到候选基向量集合

3. 贪心选择 k 个基向量：
   for t = 1 to k:
     选择使 ||M - R⊗P||_F 减少最多的候选向量作为 P 的第 t 行
     更新 R 的第 t 列：R[i][t] = 1 当且仅当该基向量覆盖用户 i 的需求
     从 M 中移除已覆盖的部分

4. 输出 R, P
```

**Python 实现**：

```python
import numpy as np
from itertools import combinations

class BooleanMatrixFactorizer:
    """布尔矩阵分解（ASSO算法改进版）"""
    
    def __init__(self, max_rank=20, tau=0.5, min_coverage=0.98):
        self.max_rank = max_rank
        self.tau = tau                  # 关联阈值
        self.min_coverage = min_coverage  # 最低覆盖率要求
    
    def fit(self, M):
        n, m = M.shape
        
        # 步骤1：计算需求项 Jaccard 关联矩阵
        association = self._compute_association(M)
        
        # 步骤2：生成候选基向量
        candidates = self._generate_candidates(association, M)
        
        # 步骤3：贪心选择最优基向量集合
        P_rows = []  # 角色/宽表定义
        R_cols = []  # 用户映射
        residual = M.copy()
        
        for t in range(self.max_rank):
            # 选择覆盖残差最多的候选
            best_idx, best_r_col, best_gain = -1, None, 0
            
            for idx, candidate in enumerate(candidates):
                # 计算该候选向量能覆盖的残差
                r_col = np.array([
                    1 if np.all(residual[i][candidate == 1] == 1) or
                         np.sum(residual[i] * candidate) / max(np.sum(candidate), 1) > 0.8
                    else 0
                    for i in range(n)
                ])
                gain = np.sum(r_col[:, None] * candidate[None, :] * residual)
                
                if gain > best_gain:
                    best_gain = gain
                    best_idx = idx
                    best_r_col = r_col
            
            if best_gain == 0:
                break
            
            P_rows.append(candidates[best_idx])
            R_cols.append(best_r_col)
            
            # 更新残差
            covered = best_r_col[:, None] * candidates[best_idx][None, :]
            residual = residual * (1 - covered)
            residual = np.clip(residual, 0, 1).astype(int)
            
            # 检查覆盖率
            P_temp = np.array(P_rows)
            R_temp = np.array(R_cols).T
            M_recon = np.clip(R_temp @ P_temp, 0, 1)
            coverage = np.sum((M_recon >= 1) & (M == 1)) / max(np.sum(M), 1)
            
            if coverage >= self.min_coverage:
                break
        
        self.role_perm_matrix = np.array(P_rows)   # k × m
        self.user_role_matrix = np.array(R_cols).T  # n × k
        self.n_roles = len(P_rows)
        
        return self
    
    def _compute_association(self, M):
        """计算需求项之间的 Jaccard 相似度"""
        m = M.shape[1]
        assoc = np.zeros((m, m))
        for j in range(m):
            for l in range(j + 1, m):
                intersection = np.sum(M[:, j] & M[:, l])
                union = np.sum(M[:, j] | M[:, l])
                assoc[j][l] = assoc[l][j] = intersection / max(union, 1)
        return assoc
    
    def _generate_candidates(self, association, M):
        """基于关联矩阵生成候选基向量"""
        m = association.shape[0]
        candidates = []
        
        # 方法1：关联矩阵行二值化
        for j in range(m):
            candidate = (association[j] >= self.tau).astype(int)
            candidate[j] = 1  # 包含自身
            if np.sum(candidate) >= 2:  # 至少包含2个需求项
                candidates.append(candidate)
        
        # 方法2：每个用户的需求项集合也作为候选
        for i in range(M.shape[0]):
            candidates.append(M[i].copy())
        
        # 去重
        candidates = list({tuple(c): c for c in candidates}.values())
        candidates = [np.array(c) for c in candidates]
        
        return candidates
    
    def evaluate(self, M):
        """评估分解质量"""
        M_recon = np.clip(self.user_role_matrix @ self.role_perm_matrix, 0, 1)
        
        total_ones = np.sum(M)
        covered_ones = np.sum((M_recon >= 1) & (M == 1))
        extra_ones = np.sum((M_recon >= 1) & (M == 0))
        
        return {
            'n_roles': self.n_roles,
            'coverage': covered_ones / max(total_ones, 1),       # 召回率
            'precision': covered_ones / max(covered_ones + extra_ones, 1),  # 精确率
            'redundancy': extra_ones / max(total_ones, 1),       # 冗余率
            'avg_role_size': np.mean(np.sum(self.role_perm_matrix, axis=1)),
            'avg_roles_per_user': np.mean(np.sum(self.user_role_matrix, axis=1)),
        }
```

**BMF 相比 NMF 的优势**：
- 直接在布尔域操作，无需二值化阈值
- 结果语义更清晰（1=有，0=无）
- 冗余更少（不会因为实数→布尔转换引入额外的 1）

---

#### 3.2.3 方案 C：形式概念分析（FCA）——追求完备性

**核心思想**：找出二值矩阵中所有**形式概念**（最大矩形1-块），从中选出最优子集。

```
形式概念 = (Extent, Intent)
  Extent：共享这些需求项的用户集合
  Intent：这些用户共同拥有的需求项集合

满足：Extent 是 Intent 的最大公共用户集，Intent 是 Extent 的最大公共需求项集
```

**Python 实现**：

```python
from concepts import Context

class FCAMiner:
    """基于形式概念分析的角色/宽表挖掘"""
    
    def __init__(self, min_extent_size=2, min_intent_size=2, max_roles=20):
        self.min_extent_size = min_extent_size  # 最少覆盖用户数
        self.min_intent_size = min_intent_size  # 最少包含需求项数
        self.max_roles = max_roles
    
    def fit(self, M, user_names=None, perm_names=None):
        n, m = M.shape
        
        if user_names is None:
            user_names = [f"u{i}" for i in range(n)]
        if perm_names is None:
            perm_names = [f"p{j}" for j in range(m)]
        
        # 构建形式上下文
        bools = [tuple(bool(M[i][j]) for j in range(m)) for i in range(n)]
        ctx = Context(user_names, perm_names, bools)
        
        # 提取所有形式概念
        all_concepts = []
        for extent, intent in ctx.lattice:
            ext_size = len(extent)
            int_size = len(intent)
            if ext_size >= self.min_extent_size and int_size >= self.min_intent_size:
                all_concepts.append({
                    'extent': set(extent),     # 用户集合
                    'intent': set(intent),     # 需求项集合
                    'coverage': ext_size * int_size,  # 覆盖面积
                })
        
        # 贪心选择：每次选覆盖最多未覆盖(user, perm)对的概念
        uncovered = set()
        for i in range(n):
            for j in range(m):
                if M[i][j] == 1:
                    uncovered.add((user_names[i], perm_names[j]))
        
        selected = []
        for _ in range(self.max_roles):
            if not uncovered:
                break
            
            best_concept = None
            best_newly_covered = set()
            
            for concept in all_concepts:
                newly_covered = set()
                for u in concept['extent']:
                    for p in concept['intent']:
                        if (u, p) in uncovered:
                            newly_covered.add((u, p))
                
                if len(newly_covered) > len(best_newly_covered):
                    best_newly_covered = newly_covered
                    best_concept = concept
            
            if best_concept is None or len(best_newly_covered) == 0:
                break
            
            selected.append(best_concept)
            uncovered -= best_newly_covered
        
        self.roles = selected
        self.uncovered_pairs = uncovered
        
        return self
    
    def get_result_summary(self):
        return {
            'n_roles': len(self.roles),
            'roles': [
                {
                    'permissions': sorted(r['intent']),
                    'users': sorted(r['extent']),
                    'n_permissions': len(r['intent']),
                    'n_users': len(r['extent']),
                }
                for r in self.roles
            ],
            'uncovered_count': len(self.uncovered_pairs),
        }
```

**FCA 的独特优势**：
- 发现的概念是**数学上精确的**最大矩形块
- 概念格展示角色之间的**继承关系**（角色 A 是角色 B 的子角色）
- 对 RBAC 角色层级设计特别有价值

**局限**：
- 概念数量可能指数级增长（最坏 2^min(n,m)）
- 适合中小规模数据（用户/权限各不超过几百）

---

### 3.3 第二层：约束优化（ILP）

第一层输出的初始方案可能违反业务约束。用**整数线性规划**进行精确优化。

#### 3.3.1 数学模型

```
决策变量：
  y_j ∈ {0,1}    —— 是否创建第 j 个角色/宽表
  x_ij ∈ {0,1}   —— 用户 i 是否分配角色 j
  p_jl ∈ {0,1}   —— 角色 j 是否包含权限/字段 l

目标函数：
  最小化  α × Σ y_j  +  β × Σ (x_ij × p_jl × (1 - M[i][l]))
          ─────────      ──────────────────────────────────────
          角色/宽表数量         冗余授权惩罚

约束条件：
  ① 完全覆盖：对每个 M[i][l]=1，至少存在一个 j 使得 x_ij=1 且 p_jl=1
  ② 角色大小限制：Σ_l p_jl ≤ MaxPermsPerRole
  ③ 用户角色数限制：Σ_j x_ij ≤ MaxRolesPerUser
  ④ 权限冲突：若权限 l1 和 l2 互斥，则不存在 j 使得 p_jl1=1 且 p_jl2=1
  ⑤ 角色使用前提：x_ij ≤ y_j（只有创建的角色才能分配）
  
  数据仓库附加约束：
  ⑥ 同表约束：同一宽表的字段必须来自可 JOIN 的原始表
  ⑦ 粒度一致：同一宽表的字段粒度必须一致
```

#### 3.3.2 Python 实现

```python
from pulp import *
import numpy as np

class ILPRoleOptimizer:
    """基于整数线性规划的角色/宽表优化器"""
    
    def __init__(self, config):
        self.config = config
    
    def optimize(self, M, initial_P=None, constraints=None):
        """
        M: 用户-需求项二值矩阵 (n×m)
        initial_P: 第一层算法输出的初始角色定义 (k×m)，用于热启动
        constraints: 业务约束字典
        """
        n, m = M.shape
        
        # 候选角色集合：来自第一层输出 + 扩展候选
        if initial_P is not None:
            k = initial_P.shape[0]
            # 可以在初始方案基础上扩展候选（如拆分、合并）
            candidate_roles = self._expand_candidates(initial_P, M)
        else:
            k = min(n, self.config.get('max_roles', 20))
            candidate_roles = self._generate_candidates_from_data(M, k)
        
        K = len(candidate_roles)
        
        # 创建 ILP 问题
        prob = LpProblem("RoleOptimization", LpMinimize)
        
        # 决策变量
        y = [LpVariable(f"y_{j}", cat='Binary') for j in range(K)]
        x = [[LpVariable(f"x_{i}_{j}", cat='Binary') 
              for j in range(K)] for i in range(n)]
        
        # 目标：最小化角色数量 + 冗余惩罚
        alpha = self.config.get('weight_num_roles', 1.0)
        beta = self.config.get('weight_redundancy', 0.01)
        
        prob += (
            alpha * lpSum(y) + 
            beta * lpSum(
                x[i][j] * candidate_roles[j][l] * (1 - M[i][l])
                for i in range(n) for j in range(K) for l in range(m)
                if candidate_roles[j][l] == 1 and M[i][l] == 0
            )
        )
        
        # 约束①：完全覆盖
        for i in range(n):
            for l in range(m):
                if M[i][l] == 1:
                    prob += lpSum(
                        x[i][j] for j in range(K) 
                        if candidate_roles[j][l] == 1
                    ) >= 1, f"cover_{i}_{l}"
        
        # 约束②：角色大小限制
        max_perms = self.config.get('max_permissions_per_role', 100)
        for j in range(K):
            if sum(candidate_roles[j]) > max_perms:
                prob += y[j] == 0, f"too_large_{j}"
        
        # 约束③：用户角色数限制
        max_roles_per_user = self.config.get('max_roles_per_user', 5)
        for i in range(n):
            prob += lpSum(x[i]) <= max_roles_per_user, f"max_roles_user_{i}"
        
        # 约束⑤：角色使用前提
        for i in range(n):
            for j in range(K):
                prob += x[i][j] <= y[j], f"use_created_{i}_{j}"
        
        # 约束④：权限冲突（若提供）
        if constraints and 'conflicts' in constraints:
            for l1, l2 in constraints['conflicts']:
                for j in range(K):
                    if candidate_roles[j][l1] == 1 and candidate_roles[j][l2] == 1:
                        prob += y[j] == 0, f"conflict_{j}_{l1}_{l2}"
        
        # 求解
        solver = PULP_CBC_CMD(msg=0, timeLimit=300)
        prob.solve(solver)
        
        # 提取结果
        selected_roles = []
        user_mappings = [[] for _ in range(n)]
        
        for j in range(K):
            if value(y[j]) == 1:
                role_idx = len(selected_roles)
                selected_roles.append(candidate_roles[j])
                for i in range(n):
                    if value(x[i][j]) == 1:
                        user_mappings[i].append(role_idx)
        
        return {
            'roles': selected_roles,
            'user_mappings': user_mappings,
            'n_roles': len(selected_roles),
            'status': LpStatus[prob.status],
            'objective': value(prob.objective),
        }
    
    def _expand_candidates(self, initial_P, M):
        """基于初始方案扩展候选角色集合"""
        candidates = list(initial_P)
        
        # 添加每个用户的原始需求作为候选
        for i in range(M.shape[0]):
            candidates.append(M[i].copy())
        
        # 添加初始角色的交集和并集
        k = initial_P.shape[0]
        for j1 in range(k):
            for j2 in range(j1 + 1, k):
                # 交集
                intersection = initial_P[j1] & initial_P[j2]
                if np.sum(intersection) >= 2:
                    candidates.append(intersection)
                # 并集
                union = initial_P[j1] | initial_P[j2]
                candidates.append(union)
        
        # 去重
        seen = set()
        unique = []
        for c in candidates:
            key = tuple(c)
            if key not in seen:
                seen.add(key)
                unique.append(np.array(c))
        
        return unique
    
    def _generate_candidates_from_data(self, M, k):
        """直接从数据生成候选角色"""
        candidates = []
        for i in range(M.shape[0]):
            candidates.append(M[i].copy())
        
        seen = set()
        unique = []
        for c in candidates:
            key = tuple(c)
            if key not in seen:
                seen.add(key)
                unique.append(np.array(c))
        
        return unique
```

---

### 3.4 第三层：评估指标体系

原方案仅有覆盖率一个指标。改进方案提供**多维度评估**：

```python
class SolutionEvaluator:
    """方案评估器"""
    
    @staticmethod
    def evaluate(M, roles, user_mappings):
        """
        M: 原始用户-需求项矩阵 (n×m)
        roles: 角色定义列表，每个元素为 长度 m 的 0/1 数组
        user_mappings: 用户-角色映射，user_mappings[i] = [角色索引列表]
        """
        n, m = M.shape
        
        # 重构矩阵
        M_recon = np.zeros_like(M)
        for i in range(n):
            for j in user_mappings[i]:
                M_recon[i] = np.clip(M_recon[i] + roles[j], 0, 1)
        
        total_required = np.sum(M)
        covered = np.sum((M_recon == 1) & (M == 1))
        extra = np.sum((M_recon == 1) & (M == 0))
        
        metrics = {
            # ─── 核心指标 ───
            'coverage_rate': covered / max(total_required, 1),     # 覆盖率（越高越好，目标≥98%）
            'precision_rate': covered / max(covered + extra, 1),   # 精确率（越高越好，冗余越少）
            'redundancy_rate': extra / max(total_required, 1),     # 冗余率（越低越好）
            
            # ─── 结构指标 ───
            'n_roles': len(roles),                                  # 角色/宽表总数
            'avg_role_size': np.mean([np.sum(r) for r in roles]),  # 平均角色大小
            'max_role_size': np.max([np.sum(r) for r in roles]),   # 最大角色大小
            'role_size_std': np.std([np.sum(r) for r in roles]),   # 角色大小方差
            
            # ─── 用户体验指标 ───
            'avg_roles_per_user': np.mean([len(m) for m in user_mappings]),  # 平均每用户角色数
            'max_roles_per_user': np.max([len(m) for m in user_mappings]),  # 最大每用户角色数
            
            # ─── 复用指标 ───
            'role_reuse_rate': np.mean([                           # 角色复用率（被多少用户共享）
                sum(1 for um in user_mappings if j in um) / n 
                for j in range(len(roles))
            ]),
        }
        
        # 综合评分（加权）
        metrics['overall_score'] = (
            metrics['coverage_rate'] * 0.35 +
            metrics['precision_rate'] * 0.25 +
            (1 - min(len(roles), 30) / 30) * 0.15 +  # 角色数量惩罚
            metrics['role_reuse_rate'] * 0.15 +
            (1 - metrics['avg_roles_per_user'] / 10) * 0.10  # 用户复杂度惩罚
        )
        
        return metrics
```

### 3.5 评估指标说明

| 指标 | 含义 | 目标值 | 权重 |
|------|------|--------|------|
| **覆盖率** | 原始需求被满足的比例 | ≥ 98% | 35% |
| **精确率** | 授权中有多少是真正需要的 | ≥ 85% | 25% |
| **冗余率** | 多余授权占总需求的比例 | ≤ 15% | — |
| **角色数量** | 总共创建了多少个角色/宽表 | 10~20 | 15% |
| **角色复用率** | 平均一个角色被多少用户共享 | ≥ 20% | 15% |
| **用户复杂度** | 平均每个用户需要几个角色 | ≤ 3 | 10% |

---

## 四、算法对比（含改进方案）

| 维度 | 频繁项集（原） | 聚类（原） | **NMF（改进）** | **BMF（改进）** | **FCA（改进）** | **ILP（改进）** |
|------|-------------|-----------|---------------|---------------|---------------|---------------|
| **直接输出结果** | ❌ 需二次加工 | ❌ 需二次加工 | ✅ 直接输出 | ✅ 直接输出 | ✅ 直接输出 | ✅ 直接输出 |
| **统一优化目标** | ❌ 无 | ❌ 无 | ✅ 最小化重构误差 | ✅ 最小化布尔误差 | ⚠️ 贪心近似 | ✅ 精确最优 |
| **支持重叠** | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| **业务约束** | ❌ 后处理 | ❌ 后处理 | ❌ 后处理 | ❌ 后处理 | ⚠️ 部分 | ✅ 完整建模 |
| **时间复杂度** | O(n×2^m) 💀 | O(k×n×m) | O(n×m×k×T) | O(n×m×k) | O(2^min(n,m)) | 取决于求解器 |
| **实现难度** | 低 | 低 | **低** | 中 | 中 | 中高 |
| **推荐度** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 五、推荐实施路径

### 5.1 快速见效路线（1~2 周）

```
步骤1：数据准备
├── 收集用户-权限/报表-字段的映射数据
├── 构建二值矩阵 M
└── 数据清洗（去重、标准化）

步骤2：NMF 快速出方案
├── 使用 NMFRoleMiner 快速获得初始方案
├── 自动搜索最优 k 值
└── 输出角色定义和用户映射

步骤3：人工评审与微调
├── 业务专家审核角色合理性
├── 调整不合理的角色组合
└── 确认最终方案
```

### 5.2 精细优化路线（3~4 周）

```
步骤1：数据准备（同上）

步骤2：BMF 获得高质量初始方案
├── 使用 BooleanMatrixFactorizer
├── 直接在布尔域上分解，无阈值问题
└── 输出初始角色方案

步骤3：ILP 约束优化
├── 将 BMF 结果作为候选输入 ILP
├── 添加业务硬约束（权限冲突、大小限制等）
├── 求解全局最优
└── 输出精确优化后的方案

步骤4：多维度评估
├── 使用 SolutionEvaluator 量化评估
├── 对比多组参数的结果
└── 选择综合评分最优的方案

步骤5：业务落地
├── 生成角色创建脚本 / 建表 SQL
├── 小范围试点
└── 全面推广
```

### 5.3 决策流程图

```
开始
  │
  ▼
数据规模如何？
  │
  ├── 小规模（用户<50, 权限<200）
  │     → FCA（精确发现所有概念）+ ILP（精确优化）
  │
  ├── 中规模（用户50~500, 权限200~2000）
  │     → NMF/BMF（快速分解）+ ILP（约束优化）  ← 【大多数场景推荐】
  │
  └── 大规模（用户>500, 权限>2000）
        → NMF（高效分解）+ 贪心后处理
  │
  ▼
是否有严格业务约束（权限冲突、字段来源限制等）？
  │
  ├── 是 → 必须加 ILP 层
  └── 否 → 分解算法直接输出即可
  │
  ▼
输出最终方案 → 多维度评估 → 业务评审 → 落地实施
```

---

## 六、增量更新机制

原方案未考虑增量场景。实际业务中，新用户入职、新报表上线是常态。

### 6.1 新用户/报表的快速匹配

```python
def assign_existing_roles(new_user_perms, existing_roles, threshold=0.9):
    """
    为新用户从现有角色中快速匹配最优组合
    
    new_user_perms: 新用户的权限向量 (1×m)
    existing_roles: 现有角色定义列表
    threshold: 覆盖率阈值
    """
    n_roles = len(existing_roles)
    
    # 贪心匹配：每次选覆盖最多未覆盖权限的角色
    uncovered = set(np.where(new_user_perms == 1)[0])
    assigned = []
    
    while uncovered:
        best_role, best_cover = -1, set()
        for j in range(n_roles):
            role_perms = set(np.where(existing_roles[j] == 1)[0])
            cover = uncovered & role_perms
            if len(cover) > len(best_cover):
                best_cover = cover
                best_role = j
        
        if not best_cover:
            break
        
        assigned.append(best_role)
        uncovered -= best_cover
        
        # 检查覆盖率
        total = np.sum(new_user_perms)
        covered = total - len(uncovered)
        if covered / total >= threshold:
            break
    
    return {
        'assigned_roles': assigned,
        'coverage': (np.sum(new_user_perms) - len(uncovered)) / max(np.sum(new_user_perms), 1),
        'uncovered_perms': list(uncovered),  # 需要额外处理的权限
    }
```

### 6.2 定期全量重算触发条件

| 触发条件 | 说明 |
|---------|------|
| 新增用户超过总量的 20% | 用户结构可能已显著变化 |
| 无法匹配的新用户累计超过 10% | 现有角色体系不足以覆盖新模式 |
| 角色平均复用率低于 10% | 角色碎片化严重 |
| 冗余率超过 25% | 过度授权风险增加 |
| 定期（每季度/半年） | 常规维护 |

---

## 七、数据仓库场景的特殊处理

### 7.1 JOIN 路径可达性约束

同一宽表的字段必须来自可以 JOIN 的原始表：

```python
def build_join_graph(table_relations):
    """
    构建原始表之间的 JOIN 关系图
    
    table_relations: [
        {"left_table": "t_order", "right_table": "t_customer", 
         "join_key": "customer_id", "join_type": "left"},
        ...
    ]
    """
    import networkx as nx
    
    G = nx.Graph()
    for rel in table_relations:
        G.add_edge(
            rel['left_table'], 
            rel['right_table'],
            join_key=rel['join_key'],
            join_type=rel['join_type']
        )
    return G

def check_joinable(fields, join_graph, max_join_depth=3):
    """
    检查一组字段所在的原始表是否可以在指定深度内 JOIN
    """
    source_tables = set(f['source_table'] for f in fields)
    
    if len(source_tables) <= 1:
        return True
    
    tables = list(source_tables)
    for i in range(len(tables)):
        for j in range(i + 1, len(tables)):
            try:
                path = nx.shortest_path(join_graph, tables[i], tables[j])
                if len(path) - 1 > max_join_depth:
                    return False
            except nx.NetworkXNoPath:
                return False
    
    return True
```

### 7.2 数据粒度一致性检查

```python
GRANULARITY_ORDER = {
    'year': 1, 'quarter': 2, 'month': 3, 'week': 4, 
    'day': 5, 'hour': 6, 'minute': 7, 'detail': 8
}

def check_granularity_compatible(fields):
    """检查字段粒度是否一致（或可兼容）"""
    granularities = set()
    for f in fields:
        if 'granularity' in f:
            granularities.add(f['granularity'])
    
    if len(granularities) <= 1:
        return True
    
    # 允许相邻粒度兼容（如 day 和 detail）
    levels = [GRANULARITY_ORDER.get(g, 0) for g in granularities]
    return max(levels) - min(levels) <= 1
```

---

## 八、技术选型与依赖

### 8.1 Python 依赖

```
# 核心算法
numpy>=1.21.0
scipy>=1.7.0
scikit-learn>=1.0.0       # NMF, 聚类, 评估指标

# ILP 求解器
PuLP>=2.7.0               # 免费 ILP 求解器（内置 CBC）
# 可选: python-mip, ortools

# 形式概念分析
concepts>=0.9.0            # FCA 实现

# 图算法（可选）
networkx>=2.6.0            # JOIN 路径检查, 社区发现

# 数据处理
pandas>=1.3.0
```

### 8.2 可选商业求解器（大规模场景）

| 求解器 | 特点 | 许可 |
|--------|------|------|
| **Gurobi** | 性能最强，学术免费 | 商业许可 |
| **CPLEX** | IBM 出品，性能优秀 | 商业许可 |
| **CBC** | PuLP 内置，够用 | 开源免费 |
| **SCIP** | 学术界主流 | 学术免费 |

---

## 九、总结

| 维度 | 原方案 | 改进方案 |
|------|--------|---------|
| **核心算法** | 频繁项集 + 聚类 | NMF/BMF + ILP |
| **优化目标** | 模糊，分阶段各自优化 | 明确，统一数学目标函数 |
| **输出** | 需二次加工 | 直接输出可用方案 |
| **重叠支持** | 不支持 | 天然支持 |
| **业务约束** | 后处理 | ILP 精确建模 |
| **评估指标** | 仅覆盖率 | 6 维指标 + 综合评分 |
| **增量更新** | 未考虑 | 快速匹配 + 定期重算 |
| **数仓特殊处理** | 配置提及但未实现 | JOIN路径 + 粒度检查 |
| **实现复杂度** | 低 | 中（但有完整代码参考） |
| **结果质量** | 中等 | 显著提升 |

**核心改进点**：用**矩阵分解**替代频繁项集作为核心算法，用**整数线性规划**替代启发式后处理实现约束优化，用**多维评估体系**替代单一覆盖率指标。这三个改变使方案从"能用"升级为"好用"。

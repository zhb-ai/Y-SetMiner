import axios from 'axios'

import type { ImportPreviewResponse, SceneInfo, SceneKey, SolveResponse } from '../types/api'

const client = axios.create({
  baseURL: '/api',
  timeout: 120000,
})

export async function fetchScenes() {
  const { data } = await client.get<SceneInfo[]>('/scenes')
  return data
}

export async function fetchDemoSolution(scene: SceneKey) {
  const { data } = await client.get<SolveResponse>(`/scenes/${scene}/demo`)
  return data
}

export async function previewErpFile(file: File) {
  const formData = new FormData()
  formData.append('file', file)
  const { data } = await client.post<ImportPreviewResponse>('/import/erp/users-permissions/preview', formData)
  return data
}

export async function solveErpFile(
  file: File,
  currentRolePermissionsFile?: File | null,
  currentUserRolesFile?: File | null,
) {
  const formData = new FormData()
  formData.append('file', file)
  if (currentRolePermissionsFile) {
    formData.append('current_role_permissions_file', currentRolePermissionsFile)
  }
  if (currentUserRolesFile) {
    formData.append('current_user_roles_file', currentUserRolesFile)
  }
  const { data } = await client.post<SolveResponse>('/import/erp/users-permissions/solve', formData)
  return data
}

export async function previewSqlFiles(files: File[]) {
  const formData = new FormData()
  files.forEach((file) => formData.append('files', file))
  const { data } = await client.post<ImportPreviewResponse>('/import/sql/documents/preview', formData)
  return data
}

export async function solveSqlFiles(files: File[]) {
  const formData = new FormData()
  files.forEach((file) => formData.append('files', file))
  const { data } = await client.post<SolveResponse>('/import/sql/documents/solve', formData)
  return data
}

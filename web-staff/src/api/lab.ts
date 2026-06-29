// Lab-worker-facing API calls (Scope §11.4).

import { api } from './client';
import type { LabQueueOrder } from './types';

export const labApi = {
  queue: () => api.get<LabQueueOrder[]>('/lab/orders'),
  markCollected: (id: string) => api.patch(`/lab/orders/${id}/collect`),
  markProcessing: (id: string) => api.patch(`/lab/orders/${id}/processing`),

  // Metadata-only (simulated) result with optional structured values.
  uploadResult: (id: string, body: Record<string, unknown>) => api.post(`/lab/orders/${id}/result`, body),

  // Real multipart upload to /lab/orders/:id/result-file (25 MB limit, P-FR-055).
  uploadResultFile: async (id: string, file: File, comments?: string) => {
    const token = localStorage.getItem('cnic_staff_token');
    const form = new FormData();
    form.append('file', file);
    if (comments) form.append('comments', comments);
    const res = await fetch(`/api/lab/orders/${id}/result-file`, {
      method: 'POST',
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
      body: form,
    });
    if (!res.ok) {
      let message = `Upload failed (${res.status})`;
      try {
        message = (await res.json()).message ?? message;
      } catch {
        /* ignore */
      }
      throw new Error(message);
    }
  },
};

import { supabase } from './supabase';

/* eslint-disable @typescript-eslint/no-explicit-any */
type Q = any;

async function rows<T>(builder: Q): Promise<T[]> {
  const { data, error } = await builder;
  if (error) throw new Error(error.message);
  return (data ?? []) as T[];
}

export interface ResearchOrg {
  id: string;
  name: string;
  organization_type: string;
  registration_number: string | null;
  country: string | null;
  contact_email: string | null;
  website: string | null;
  dpa_accepted_at: string | null;
  dpa_version: string | null;
  status: string;
  status_reason: string | null;
  created_at: string;
}

export interface AdminDataRequest {
  id: string;
  title: string;
  research_purpose: string;
  legal_basis: string;
  cohort_filters: Record<string, string | null>;
  ethics_approval_reference: string | null;
  dpa_accepted: boolean;
  status: string;
  decision_note: string | null;
  decided_at: string | null;
  expires_at: string | null;
  export_count: number;
  last_exported_at: string | null;
  created_at: string;
  organization: { name: string; status: string; organization_type: string } | null;
  dataset: { code: string; name: string; grain: string } | null;
  requester: { full_name: string; email: string | null } | null;
}

export const researchAdminApi = {
  organizations(): Promise<ResearchOrg[]> {
    return rows<ResearchOrg>(
      supabase.from('research_organizations').select('*').order('created_at', { ascending: false }),
    );
  },

  async setOrganizationStatus(id: string, status: string, reason?: string): Promise<void> {
    const patch: Record<string, unknown> = {
      status,
      status_reason: reason?.trim() || null,
    };
    if (status === 'active') patch.approved_at = new Date().toISOString();
    const { error } = await supabase.from('research_organizations').update(patch).eq('id', id);
    if (error) throw new Error(error.message);
  },

  dataRequests(): Promise<AdminDataRequest[]> {
    return rows<AdminDataRequest>(
      supabase
        .from('research_data_requests')
        .select(
          '*, organization:research_organizations(name, status, organization_type), ' +
            'dataset:research_datasets(code, name, grain), requester:profiles!requested_by(full_name, email)',
        )
        .order('created_at', { ascending: false }),
    );
  },

  /**
   * Decisions go through the RPC rather than a direct update so the
   * notification to the requester and the audit row are written atomically
   * with the status change.
   */
  async decide(
    requestId: string,
    status: 'approved' | 'rejected' | 'revoked',
    note: string | null,
    validDays: number,
  ): Promise<void> {
    const { error } = await supabase.rpc('admin_decide_data_request', {
      p_request: requestId,
      p_status: status,
      p_note: note?.trim() || null,
      p_valid_days: validDays,
    });
    if (error) throw new Error(error.message);
  },
};

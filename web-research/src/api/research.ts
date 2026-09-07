import { supabase } from './supabase';
import type {
  CohortBucket,
  CohortFilters,
  CohortSize,
  DataRequest,
  PrevalenceRow,
  ResearchDataset,
} from './types';

/* eslint-disable @typescript-eslint/no-explicit-any */
type Q = any;

async function rows<T>(builder: Q): Promise<T[]> {
  const { data, error } = await builder;
  if (error) throw new Error(error.message);
  return (data ?? []) as T[];
}

async function rpc<T>(fn: string, params: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await supabase.rpc(fn, params);
  if (error) throw new Error(error.message);
  return data as T;
}

/** Filters are sent as explicit nulls so Postgres defaults apply cleanly. */
function filterParams(f: CohortFilters) {
  return {
    p_gender: f.gender || null,
    p_province: f.province || null,
    p_age_band: f.age_band || null,
  };
}

export const researchApi = {
  // ── Aggregate tier (no approval needed) ───────────────────────────────────
  async cohortSize(filters: CohortFilters): Promise<CohortSize> {
    const data = await rpc<CohortSize[]>('research_cohort_size', filterParams(filters));
    return data?.[0] ?? { subject_count: 0, suppressed: false };
  },

  cohortBreakdown(dimension: string, filters: CohortFilters): Promise<CohortBucket[]> {
    return rpc<CohortBucket[]>('research_cohort_summary', {
      p_dimension: dimension,
      ...filterParams(filters),
    });
  },

  conditionPrevalence(): Promise<PrevalenceRow[]> {
    return rpc<PrevalenceRow[]>('research_condition_prevalence');
  },

  // ── Catalogue ─────────────────────────────────────────────────────────────
  datasets(): Promise<ResearchDataset[]> {
    return rows<ResearchDataset>(
      supabase.from('research_datasets').select('*').order('code'),
    );
  },

  // ── Requests ──────────────────────────────────────────────────────────────
  myRequests(): Promise<DataRequest[]> {
    return rows<DataRequest>(
      supabase
        .from('research_data_requests')
        .select('*, dataset:research_datasets(code, name, grain)')
        .order('created_at', { ascending: false }),
    );
  },

  async createRequest(input: {
    organization_id: string;
    dataset_id: string;
    title: string;
    research_purpose: string;
    legal_basis: string;
    ethics_approval_reference: string | null;
    cohort_filters: CohortFilters;
  }): Promise<void> {
    const { error } = await supabase.from('research_data_requests').insert({
      ...input,
      // The database trigger forces status/salt regardless of what we send;
      // the agreement flag is what the insert policy actually checks.
      dpa_accepted: true,
    });
    if (error) throw new Error(error.message);
  },

  // ── Record-level export (approved requests only) ──────────────────────────
  // The function name is chosen by dataset code; every one of them re-checks
  // approval, organisation ownership and expiry server-side.
  exportRows(datasetCode: string, requestId: string): Promise<Record<string, unknown>[]> {
    const fn = {
      patient_features: 'research_export_patient_features',
      conditions: 'research_export_conditions',
      observations: 'research_export_observations',
    }[datasetCode];
    if (!fn) throw new Error(`No exporter is defined for dataset "${datasetCode}".`);
    return rpc<Record<string, unknown>[]>(fn, { p_request: requestId });
  },
};

// ── Client-side file building ───────────────────────────────────────────────

function escapeCsv(value: unknown): string {
  if (value === null || value === undefined) return '';
  const s = String(value);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function toCsv(data: Record<string, unknown>[]): string {
  if (!data.length) return '';
  const headers = Object.keys(data[0]);
  const lines = [headers.join(',')];
  for (const row of data) lines.push(headers.map((h) => escapeCsv(row[h])).join(','));
  return lines.join('\n');
}

export function toJsonl(data: Record<string, unknown>[]): string {
  return data.map((row) => JSON.stringify(row)).join('\n');
}

/**
 * A provenance manifest shipped alongside every download, so an extract is
 * never separated from the terms it was released under.
 */
export function buildManifest(req: DataRequest, rowCount: number, format: string) {
  return JSON.stringify(
    {
      dataset: req.dataset?.code ?? req.dataset_id,
      dataset_name: req.dataset?.name ?? null,
      grain: req.dataset?.grain ?? null,
      request_id: req.id,
      request_title: req.title,
      research_purpose: req.research_purpose,
      legal_basis: req.legal_basis,
      cohort_filters: req.cohort_filters,
      approved_at: req.decided_at,
      access_expires_at: req.expires_at,
      exported_at: new Date().toISOString(),
      row_count: rowCount,
      format,
      privacy: {
        basis: 'Explicit opt-in research consent, verified at query time.',
        pseudonymisation:
          'subject_id is a per-request salted digest. It is NOT stable across requests, so extracts cannot be linked.',
        generalisation:
          'Ages are 5-year bands, locations are province-level, observation dates are year-month.',
        excluded:
          'No name, CNIC, Hayaat ID, phone, email, address, date of birth, clinical free text, documents or messages.',
        k_anonymity: 'Aggregate counts below k=5 are suppressed.',
        conditions_of_use:
          'Re-identification, or attempting to link this extract to any other dataset or person, is prohibited.',
      },
    },
    null,
    2,
  );
}

export function downloadFile(filename: string, content: string, mime: string) {
  const url = URL.createObjectURL(new Blob([content], { type: mime }));
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

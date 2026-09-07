export type RequestStatus = 'pending' | 'approved' | 'rejected' | 'expired' | 'revoked';
export type OrgStatus = 'pending' | 'active' | 'suspended' | 'rejected';

export interface ResearchOrganization {
  id: string;
  name: string;
  organization_type: string;
  registration_number: string | null;
  country: string | null;
  contact_email: string | null;
  website: string | null;
  dpa_accepted_at: string | null;
  dpa_version: string | null;
  status: OrgStatus;
  status_reason: string | null;
  created_at: string;
}

export interface ResearcherUser {
  id: string;
  full_name: string;
  email: string | null;
  role: string;
  status: string;
  extended: {
    organization_id: string | null;
    job_title: string | null;
    is_org_admin: boolean;
    organization: ResearchOrganization | null;
  } | null;
}

export interface DictionaryColumn {
  column: string;
  type: string;
  description?: string;
}

export interface ResearchDataset {
  id: string;
  code: string;
  name: string;
  description: string;
  tier: 'aggregate' | 'record_level';
  grain: string;
  dictionary: DictionaryColumn[];
}

export interface DataRequest {
  id: string;
  organization_id: string;
  dataset_id: string;
  requested_by: string;
  title: string;
  research_purpose: string;
  legal_basis: 'consent' | 'public_interest' | 'legitimate_interest';
  cohort_filters: CohortFilters;
  ethics_approval_reference: string | null;
  dpa_accepted: boolean;
  status: RequestStatus;
  decision_note: string | null;
  decided_at: string | null;
  expires_at: string | null;
  export_count: number;
  last_exported_at: string | null;
  created_at: string;
  dataset?: Pick<ResearchDataset, 'code' | 'name' | 'grain'> | null;
}

export interface CohortFilters {
  gender?: string | null;
  province?: string | null;
  age_band?: string | null;
}

/** A k-anonymised bucket. `subject_count` is null exactly when suppressed. */
export interface CohortBucket {
  bucket: string;
  subject_count: number | null;
  suppressed: boolean;
}

export interface CohortSize {
  subject_count: number | null;
  suppressed: boolean;
}

export interface PrevalenceRow {
  condition_group: string;
  subject_count: number | null;
  suppressed: boolean;
}

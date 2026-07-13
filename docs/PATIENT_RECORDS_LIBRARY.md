# Patient Records Library

## Navigation model

The patient records experience uses a three-level folder pattern:

1. **Records library** — only specialties containing at least one patient record are displayed.
2. **Specialty folder** — records are grouped by year, sorted newest first, and filterable by record type.
3. **Record viewer** — the original image/PDF or a structured clinical document is shown with its metadata.

The existing Prescriptions and Reports tabs remain available as focused shortcuts. They read the same underlying clinical sources.

## Specialty taxonomy

`lib/models/medical_specialty.dart` is the single patient-facing taxonomy. It contains broad head-to-toe domains and aliases for clinical provider terminology. New encounter forms use the same canonical names, while older values are normalized through alias matching.

Specialties are never created from a static UI list. A folder becomes active only when `RecordController.medicalRecords` contains a record with that specialty ID.

## Record sources

The normalized index merges:

- finalized encounters and consultation notes;
- prescriptions grouped by encounter;
- vital signs and observations;
- chronic diagnoses;
- released laboratory and imaging results;
- allergy records;
- original documents stored in `medical_documents`.

`supabase/patient_records.sql` adds the generic document table and private `medical-documents` bucket. Database rows store object paths, not long-lived signed URLs. The app creates a short-lived signed URL when the patient opens their library.

## Viewer behavior

- PDFs scroll through all pages using `pdfrx`.
- Medical images retain their source resolution and support pan and zoom.
- Multiple attached files are selected from a clearly labelled file switcher.
- Digital prescriptions render from the exact stored medication and doctor-footer fields.
- Desktop/tablet layouts keep metadata in a side panel; narrow layouts place it below the document.

## Accessibility

- Folder and record cards have descriptive semantic labels.
- Touch targets are at least 44 logical pixels.
- Text uses the shared Manrope scale and theme-aware contrast tokens.
- Record type is communicated with text as well as color and icon.
- Empty, loading, error, and no-search-result states are distinct.

import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
// Research portal. Talks directly to Supabase, but — unlike the admin and staff
// portals — it can only reach data through the SECURITY DEFINER research_*
// functions, which enforce consent, de-identification and k-anonymity in the
// database itself. Supabase config comes from VITE_SUPABASE_* (see .env.example).
export default defineConfig({
    plugins: [react()],
    server: {
        port: 5175,
        // src/index.css imports ../../shared-ui/theme.css, which lives outside this
        // app's root — the dev server needs explicit permission to serve it.
        fs: { allow: ['..'] },
    },
});

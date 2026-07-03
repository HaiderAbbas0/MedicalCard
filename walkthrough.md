> ⚠️ **HISTORICAL — describes the retired in-memory Node/Express prototype.**
> The production architecture is now **Supabase-first** (see the root `README.md`
> and `supabase/SUPABASE_SETUP.md`). The `/backend` folder this document refers to
> has been removed. Kept only as a record of the earlier prototype.

# Walkthrough — Backend Authentication & UI Data Integration

We have resolved the placeholder login issues and fully bound the authenticated user session to the app's UI screens.

---

## Changes Made

1. **In-Memory Mock Database & Validation** in [auth_service.dart](file:///d:/MedicalCard/lib/services/auth_service.dart):
   - Added an in-memory `_mockUsers` database seeded with a default user (`ayesha@example.com` / `password123`).
   - Refactored `login` to check the credentials against `_mockUsers`. If the credentials match, it logs in with the correct user model. If not, it throws an `ApiException` ("Invalid email/phone or password").
   - Refactored `register` to ensure the email or phone is not already registered in `_mockUsers`. If available, it creates a new record in `_mockUsers` and assigns a custom health ID (e.g. `PK-HC-XXXX`).

2. **Model Dynamic Mapping** in [mock_data.dart](file:///d:/MedicalCard/lib/data/mock_data.dart):
   - Created a `UserPatientExtension` on `UserModel` (`toPatient()`) to map active session details directly to a `Patient` object used by the frontend view layer.
   - Dynamicized the QR code content formatting in `HealthCardWidget` to output dynamic patient payload (`healthId|name|blood|dob`).

3. **Dashboard Session Binding** in [dashboard_screen.dart](file:///d:/MedicalCard/lib/screens/dashboard/dashboard_screen.dart):
   - Replaced hardcoded `mockPatient` references with the currently logged-in user profile from `AuthController`.
   - Binds the welcome header, initials avatar, and card widget to the user's active session.

4. **Profile & Edit Profile Session Binding** in [profile_screen.dart](file:///d:/MedicalCard/lib/screens/profile/profile_screen.dart) & [edit_profile_screen.dart](file:///d:/MedicalCard/lib/screens/profile/edit_profile_screen.dart):
   - Reads the logged-in user details (`name`, `phone`, `bloodGroup`, `initials`) to populate the fields dynamically.

5. **Health Card Details Binding** in [health_card_screen.dart](file:///d:/MedicalCard/lib/screens/card/health_card_screen.dart):
   - Reads the active user profile to dynamically draw the full digital health card and generate the matching QR code graphic.

6. **Cleaned Lint Warnings**:
   - Fixed `use_null_aware_elements` warnings in `auth_service.dart` by using the conditional map value marker syntax.
   - Cleaned up an unused import of `cupertino.dart` in `app_theme.dart`.
   - Verified that `flutter analyze` runs with **0 errors or warnings**.

---

## Verification Plan & What to Test

### 1. Test Login with Registered vs Unregistered Credentials
- Run the app and go to the login screen.
- Try to login with **unregistered details** (e.g., `abc@gmail.com` with `abc123`).
- **Expected**: You should see a SnackBar showing **"Invalid email/phone or password"**.
- Try to login with the default registered user (`ayesha@example.com` with `password123`).
- **Expected**: Login is successful. The dashboard, profile, and health card screens show **Ayesha Khan** with her corresponding health records.

### 2. Test Registration of a Custom User
- Log out, and go to the Sign Up screen.
- Register a new account with custom details:
  - **Full name**: `Muhammad Bilal`
  - **Email**: `bilal@example.com`
  - **Password**: `password123`
  - **Phone number**: `03123456789`
- Press **Continue** and verify the OTP using `123456`.
- **Expected**: You are logged in. The dashboard header and avatar now correctly display **Muhammad Bilal** with the initials **MB**.
- Navigate to **Health Card** or **Profile** tabs and verify the custom name, email, and matching QR code are displayed.

# Security setup – AutoSpare Hub

This app uses **Firebase Authentication** for both apps and **strict Firestore /
Realtime Database rules**. Passwords are never stored in Firestore or on the phone.

## How it works

| Piece | Purpose |
|---|---|
| Firebase Auth (Email/Password) | Verifies passwords. Users still log in with **phone + password**; the app turns the phone into an internal e-mail (`c9876543210@autosparehub.app` for customers, `aad…@autosparehub.app` for admins). These are not real mailboxes. |
| `LOGIN_INDEX/{key}` | Maps a phone to its sign-in e-mail (`C91…` customers, `A…` admins). Readable one at a time, never listable. |
| `USERS/{USR_91…}.AUTH_UID` | The sign-in that owns a customer record. An admin password reset creates a new sign-in and swaps this, so the old password stops working immediately. |
| `ROLES/{uid}` | `{ ADMIN_ID, ROLE: MANAGER/STAFF, IS_ACTIVE }`. The rules use it to decide what an admin may do. Only MANAGERs can change it. |
| App Check | Lets Firebase reject requests that do not come from the real app. |
| `firestore.rules`, `database.rules.json` | The rules. Tested in `security_tests/`. |

## One-time setup (do these in order)

Deploying the rules before steps 1–3 would lock everyone out.

### 1. Turn on Email/Password sign-in
Firebase console → **Authentication** → Get started → **Sign-in method** →
**Email/Password** → Enable → Save. Leave "Email link" off.
Under **Settings → User actions**, keep **Email enumeration protection** on.

### 2. Remove the old test data
The old records contain plain-text passwords. In **Firestore**, delete the
`ADMINS`, `USERS` and `CARTS` collections (or every document with a `PASSWORD`
field). Orders/products can stay.

### 3. Create the first MANAGER (manual, once)
Admins can only be created by a manager, so the first one is made by hand.
Replace `9876543210` with the manager's phone and pick a strong password.

1. **Authentication → Users → Add user**
   e-mail `aad1@autosparehub.app`, password of your choice → copy the **User UID**.
2. **Firestore → Start collection `ADMINS`**, document ID `AD1`:
   `ID: "AD1"`, `NAME: "Owner"`, `PHONE_NUMBER: "9876543210"`, `TYPE: "MANAGER"`,
   `IS_ACTIVE: true` (boolean), `AUTH_UID: "<uid>"`, `AUTH_EMAIL: "aad1@autosparehub.app"`
3. **Collection `ROLES`**, document ID = `<uid>`:
   `ADMIN_ID: "AD1"`, `ROLE: "MANAGER"`, `IS_ACTIVE: true` (boolean)
4. **Collection `LOGIN_INDEX`**, document ID `A9876543210`:
   `EMAIL: "aad1@autosparehub.app"`

Log in to the admin app with `9876543210` + that password. Every other admin
and customer is created from the app from now on.

### 4. Deploy the rules
```bash
firebase login
firebase deploy --only firestore:rules,database
```
Old app versions stop working after this (they used the insecure login).
Bump `version:` in `pubspec.yaml` and use the Realtime Database lock (`/0`
`ADMIN_VERSIONS` / `USER_VERSIONS`) to force everyone onto the new build.

### 5. App Check (blocks scripts that use your public API key)
1. **App Check → Apps** → register both Android apps with **Play Integrity**.
   Add the **SHA-256** of your release signing key under Project settings →
   your Android apps (for Play Store builds, also the Play App Signing key).
2. Debug builds print `Enter this debug secret into the allow list…` in the log.
   Add that token under App Check → Apps → ⋮ → **Manage debug tokens**.
3. Watch **App Check → APIs → metrics** for a few days. When nearly all
   requests are "verified", click **Enforce** for **Cloud Firestore**,
   **Realtime Database** and **Authentication**.

### 6. Restrict the API key
Google Cloud console → **APIs & Services → Credentials** → the Android key:
* Application restrictions: **Android apps** → add `com.codemates.auto_spare_hub`
  and `com.codemates.auto_spare_hub_admin` with their SHA-1 fingerprints.
* API restrictions: Restrict key → Identity Toolkit, Token Service,
  Cloud Firestore, Firebase Realtime Database, Firebase Installations,
  FCM Registration, Firebase App Check.

### 7. Cloudinary uploads
Uploads use an **unsigned preset** (`AutoSpareHub`), so anyone who extracts it can
upload. Signed uploads need a server (not available on the Spark plan). Limit
the damage in Cloudinary → Settings → Upload → the preset:
* Allowed formats: `jpg, png, webp` · Max file size: e.g. 5 MB
* Folder: `autospare` · "Use filename"/"Overwrite": off
* Enable "Auto moderation" if available, and check usage regularly.

## Password resets
* **Customer forgot password:** Admin app → Customers → **Password** → set a new
  one and tell the customer. The old password stops working at once.
* **Admin forgot password:** a MANAGER edits the admin and fills **New Password**.
* Customers can change their own password in the app (current password required).

## Testing the rules
```bash
cd security_tests
npm install
npm test        # starts the Firestore emulator and runs rules.test.js
```
Run this after every change to `firestore.rules`.

## Known limitations (Spark plan)
* Order prices are calculated in the app; the rules check ownership and status
  but cannot re-price items. Check totals when confirming an order.
* There is no SMS (OTP) check that a customer owns the phone number they register;
  admin approval is the safeguard.
* Admin password resets leave the old, now-powerless sign-in account behind.
  You may delete old users in Authentication → Users occasionally (optional).

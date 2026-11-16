Early test build: **not 1.0 yet**. Expect rough edges.

**Download:** `upme-*-arm64-v8a.apk` (64-bit ARM only, so it works on any modern phone).
`*-debug-symbols.zip` is only needed to decode crash stack traces (the Dart code is obfuscated).

### Install & set up
1. Open the APK and allow "Install unknown apps" for your browser / file manager.
2. **Android 13+ sideloaded apps:** Notification access is greyed out ("Restricted setting") until you allow it:
   *Settings → Apps → UpMe → ⋮ (top right) → Allow restricted settings*.
3. In UpMe: *Settings → Auto-capture* → grant **Notification access** and **Display over other apps**.
4. *Wallet* → add your bank / e-wallet / card accounts (last 4 digits + linked app help the brain a lot).

### Vivo / OriginOS / Funtouch OS
These phones kill background services aggressively. For reliable capture:
- *Settings → Battery → Background power consumption management → UpMe → Allow*
- *i Manager → App manager → Auto-start manager → UpMe → On*
- Lock UpMe in the recent apps screen (pull the card down / tap the lock icon).

### Feedback
If a notification is misread, copy its text into *Settings → Brain playground* and send it over.

# ENGINE DOWNLOAD & ASSET LIFECYCLE ARCHITECTURE
## Sovereign Asset Management, Integrity Verification, and Storage Accounting

---

### 1. Architectural Philosophy

ChessCrack operates under strict local-first and privacy-respecting principles. Engines and neural network weights are treated as first-class, sovereign assets:
- **No Hidden Background Pulls:** Network downloads are initiated exclusively upon explicit user command.
- **Direct Repositories:** Assets are retrieved directly from official upstream open-source releases (Stockfish, Leela Chess Zero, and Maia Chess on GitHub/HuggingFace/Lichess).
- **Cryptographic Verification:** Every downloaded artifact is validated against official SHA-256 digests prior to installation.
- **Granular Storage Accounting:** Real-time visibility of local disk space consumed, with one-tap uninstallation and clean temp file deletion.

---

### 2. Asset Lifecycle State Machine

```
              ┌───────────────┐
              │ Not Installed │
              └───────┬───────┘
                      │ User taps "Download"
                      ▼
              ┌───────────────┐
       ┌─────►│  Downloading  │◄──────┐
       │      └───────┬───────┘       │
Resume │              │ User pauses   │ User resumes
       │              ▼               │
       │      ┌───────────────┐       │
       └──────┤    Paused     ├───────┘
              └───────┬───────┘
                      │ User cancels
                      ▼
              ┌───────────────┐
              │   Cancelled   │
              └───────┬───────┘
                      │ Download completes (100%)
                      ▼
              ┌───────────────┐
              │   Verifying   │ (SHA-256 digest calculation)
              └───────┬───────┘
         Checksum OK  │  Checksum Mismatch
     ┌────────────────┴────────────────┐
     ▼                                 ▼
┌───────────────┐             ┌───────────────┐
│   Installed   │             │ Error / Corrupt│
└───────┬───────┘             └───────────────┘
        │ User taps "Delete"
        ▼
┌───────────────┐
│ Not Installed │ (File unlinked, storage freed)
└───────────────┘
```

---

### 3. File Integrity & Atomic Installation

1. **Staged Temporary Files:** Downloads write to `<target_path>.tmp` to prevent corrupted or partially downloaded binaries from being executed.
2. **Atomic Promotion:** Once the transfer concludes and the computed SHA-256 matches the expected digest, the file is atomically renamed to its destination path.
3. **Execution Permissions:** On Android and POSIX platforms, appropriate executable bits (`chmod 755`) are set programmatically before invoking the binary.
4. **Resilient Cleanup:** If an installation fails, cancels, or encounters an unexpected exception, `.tmp` residue is automatically purged from the device filesystem.

---

### 4. Storage Counter & Deletion Hooks

Located in `lib/services/engine_download_service.dart`:
- Tracks size of each installed binary and network weight on disk.
- Exposes `onBeforeDelete` lifecycle hooks ensuring active engine processes are safely shut down prior to file unlinking.
- Updates device storage counters reactively in the settings UI.

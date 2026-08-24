# AVA Laptop Setup Instructions

## 🚀 Quick Start - AVA überall ausführen

AVA ist jetzt konfiguriert, um **überall auszuführen** - auf GitHub und auf Ihrem Laptop!

---

## 📋 GitHub Actions (Automatische Ausführung)

Das Workflow `ava-run.yml` führt AVA automatisch aus auf:
- ✅ **Linux** (Ubuntu Latest)
- ✅ **Windows** (Windows Latest)
- ✅ **macOS** (macOS Latest)
- ✅ **Safe Local Node** Mode

**Triggert automatisch bei:**
- Push auf `main` oder `develop` Branches
- Pull Requests auf `main`
- Manuelles Trigger via "Actions" Tab
- Stündlich (Schedule)

📍 View: https://github.com/hv2znbvdy9-glitch/AVA/actions

---

## 💻 Laptop Setup (Lokale Ausführung als Admin)

### Linux:
```bash
cd /path/to/AVA
sudo bash .github/scripts/ava-laptop-setup.sh
```

### macOS:
```bash
cd /path/to/AVA
sudo zsh .github/scripts/ava-laptop-setup.zsh
```

### Windows (Run as Administrator):
1. Öffnen Sie **Command Prompt** als Administrator
   - Windows 10/11: Drücken Sie `Win + X`, wählen Sie "Terminal (Admin)" oder "Command Prompt (Admin)"
2. Navigieren Sie zum AVA Verzeichnis:
   ```cmd
   cd C:\path\to\AVA
   ```
3. Führen Sie aus:
   ```cmd
   .github\scripts\ava-laptop-setup.bat
   ```

---

## ✨ Was wird ausgeführt?

Jedes Setup-Skript führt automatisch aus:

1. **npm install** - Installiert alle Abhängigkeiten
2. **npm test** - Führt alle Tests aus (54 passing, 0 failing)
3. **npx ava "echo..."** - Testet die CLI
4. **npx ava --safe-local-node** - Sichere Node Ausführung

---

## 🔑 Admin-Berechtigungen

- ✅ GitHub Actions hat `read` & `write` Permissions
- ✅ Laptop-Skripte erfordern Admin/root Rechte
- ✅ Alle Workflows können manuell getriggert werden

---

## 📊 Status überprüfen

### GitHub:
https://github.com/hv2znbvdy9-glitch/AVA/actions

### Lokal nach Setup:
```bash
npm test
npx ava "echo test"
```

---

## 🎯 Zusammenfassung

| Ort | Status | Trigger |
|-----|--------|---------|
| **GitHub (Linux)** | ✅ Automatisch | Push/PR/Manual |
| **GitHub (Windows)** | ✅ Automatisch | Push/PR/Manual |
| **GitHub (macOS)** | ✅ Automatisch | Push/PR/Manual |
| **Laptop (Linux - Admin)** | ✅ Manuell | sudo |
| **Laptop (macOS - Admin)** | ✅ Manuell | sudo |
| **Laptop (Windows - Admin)** | ✅ Manuell | Run as Administrator |

---

## 🚀 AVA läuft jetzt überall!

**GitHub Actions Workflow:** `.github/workflows/ava-run.yml`  
**Laptop Setup Skripte:** `.github/scripts/`
  - `ava-laptop-setup.sh` (Linux/Bash)
  - `ava-laptop-setup.zsh` (macOS)
  - `ava-laptop-setup.bat` (Windows)

All configured as Admin! ✅

---

## 📝 Related Issue

See Issue #151: https://github.com/hv2znbvdy9-glitch/AVA/issues/151

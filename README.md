<div align="center">

# Muster

**Free, offline attendance and salary software for Windows.**
Mark attendance, calculate salaries, track advances, and print salary slips for your workers. Everything stays on your computer.

[Download](https://github.com/lumio-apps/muster/releases/latest) · [Report a problem](https://github.com/lumio-apps/muster/issues) · aditym02@outlook.com

</div>

---

## Why Muster

Small shops, workshops and factories often keep attendance in a notebook and work out salaries on a calculator. Muster replaces that with one simple program:

- **No internet needed.** It works fully offline. The only network call is the optional "Check for updates" button.
- **No account, no cloud, no ads, no tracking.** Your workers' data never leaves your computer.
- **Free and open source.** Nothing to buy, no subscription.
- **Made for daily use.** One click per worker, and the salary is ready at month end.

## Features

### Attendance
- Mark every worker **Present / Absent / Half day / Leave** with one click, or **Mark all present**.
- Set exact check-in and check-out times. Overtime is worked out automatically in half-hour steps.
- **Late arrivals** are flagged when check-in is after work start plus the late grace.
- Go back to any earlier day to fix a mistake.
- Company holidays and weekly offs are recognised, so those days are never counted as absent.

### Workers
- Name, role, phone, joining date and photo.
- Three pay types: **daily wage**, **monthly salary**, **hourly**.
- Own overtime rate, own working hours and own weekly off for each worker, or follow the company defaults.
- Mark a worker inactive instead of deleting, so old salary records stay correct.

### Salary
- Month-by-month salary for every worker, with a clear day-by-day breakdown.
- **Advances** (money given in advance) are tracked and recovered from salary.
- **Bonus and fines**, with a reason, per worker per month.
- Optional automatic **fine for each late arrival**.
- **Company holidays**: paid for daily and hourly workers (can be switched off), always included for monthly workers.
- **Mark as paid** locks in the amount. If attendance, a bonus or a fine changes later, Muster warns you.

### Reports
- **Salary slip (PDF)**, one page per worker, with your company name and address.
- **Monthly attendance (PDF)**, a day-by-day table.
- **Salary sheet (Excel)**, with a salary sheet and an attendance sheet, ready for your accountant.
- Choose all workers or only some of them.

### Backup and security
- **Password-protected backup** of all data and photos in a single `.mbk` file (AES-256-GCM). Restore it on the same or another computer.
- Restoring never deletes your current data. It is first moved to a safety folder.
- **PIN lock** with automatic locking when the computer is idle, a "Lock now" button, and a recovery code.
- A backup password or a recovery code that is lost **cannot be recovered**. Keep them somewhere safe.

### Currencies
More than 70 currencies to choose from, including Armenian Dram (AMD), Indian Rupee (INR), US Dollar, Euro and more.

### Safe updates
Muster can update itself from inside the app. Every update is downloaded over HTTPS and installed **only after its digital signature is verified**. Your data is never touched by an update.

## Install

1. Open the [latest release](https://github.com/lumio-apps/muster/releases/latest).
2. Download `Muster-vX.Y.Z-windows.zip`.
3. Extract the zip to a folder of your choice, for example `C:\Muster`.
4. Run `muster.exe`.

Requires Windows 10 or Windows 11 (64-bit). No installer and no administrator rights are needed.

> **Windows SmartScreen:** because Muster is a free open-source program without a paid publisher certificate, Windows may show "Windows protected your PC" the first time. Choose **More info → Run anyway**.

### First start
A short setup asks for your company name, currency, working hours, weekly off and overtime rate. You can change all of it later in **Settings**.

## Your data

| What | Where |
| --- | --- |
| Database | `%APPDATA%\Muster\muster.db` |
| Worker photos | `%APPDATA%\Muster\photos` |
| Safety copies made by Restore | `%APPDATA%\Muster\restore-backups` |

**Settings → Open data folder** takes you straight there. Updating or replacing the program files never deletes this folder.

> **Back up regularly.** Use **Settings → Create backup** and keep a copy on a USB stick or another drive. Muster shows when you last made one.

## How salary is calculated

| Pay type | Formula |
| --- | --- |
| **Daily** | rate × (present days + ½ × half days + paid leave days + paid holidays) |
| **Monthly** | rate ÷ days in month × (days since joining − absent − ½ × half days − unpaid leave). Weekly offs and holidays are paid. |
| **Hourly** | rate × (hours worked + half days + paid leave + paid holidays, counted at standard day hours) |

- **Overtime** = overtime hours × normal hourly pay × the worker's overtime rate. Overtime counts in steps of half an hour. Less than 30 minutes is ignored.
- **Net pay** = base pay + overtime + bonus − fines − late fine − advance recovered. Salary never goes below zero.
- Days that are in the future, before the joining date, or a weekly off are never counted as "not marked".

## Good to know

- **Windows only**, and the screens are in **English** for now.
- The **PIN protects the Muster window**, not the data file. Keep your Windows login protected as well. Encrypting the database itself is planned.
- Reports print worker names best in English letters. Some scripts, such as Devanagari, may not shape correctly in the PDF.
- The backup file and the update check are the only places data leaves the app, and only when you ask for them.

## Build from source

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/desktop) (stable channel) with Windows desktop support.

```bash
git clone https://github.com/lumio-apps/muster.git
cd muster
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Build a release version:

```bash
flutter build windows --release
```

The program is created in `build\windows\x64\runner\Release`.

### Project layout

```
lib/
  main.dart            App start, lock screen switch
  db.dart              SQLite database and upgrades
  state.dart           App state (settings, workers, attendance, money)
  salary.dart          Salary rules (pure code, fully tested)
  salary_lines.dart    Salary lines used by the screens and reports
  backup*.dart         Encrypted backup and restore
  security.dart        PIN and recovery code hashing
  updater.dart         Signed in-app updater
  reports/             PDF and Excel reports
  ui/                  All screens
test/                  Unit tests
tool/                  Key generation and signing scripts
```

## Releasing a new version

Releases are built by GitHub Actions when a version tag is pushed.

1. Change `version:` in `pubspec.yaml`, for example `1.6.0+7`.
2. Commit and push. The **Build** workflow checks that everything compiles.
3. Create and push the tag:
   ```bash
   git tag v1.6.0
   git push origin v1.6.0
   ```
4. The **Release** workflow analyzes, tests, builds, zips, signs and publishes `Muster-v1.6.0-windows.zip` with its `.sig` file.

The tag must match the version in `pubspec.yaml`, otherwise the release stops.

### Update signing (one-time setup)

```bash
dart run tool/gen_keys.dart
```

- Put the **public key** in `lib/config.dart` (`kUpdatePublicKey`).
- Save the **private key** as the repository secret `UPDATE_SIGNING_KEY` (Settings → Secrets and variables → Actions).
- Never commit the private key. If it is lost, existing installations cannot verify new updates, and users must install a new version by hand.

## Roadmap

- Month grid view and Excel/CSV import of workers
- Dashboard with today's summary
- Encrypted database
- More languages (Hindi, Armenian, Russian)
- Dark mode
- Installer
- Automatic backups
- Loans with monthly instalments, yearly report

## Contributing

Bug reports, ideas and pull requests are welcome. Please open an [issue](https://github.com/lumio-apps/muster/issues) first for bigger changes. Run `flutter analyze` and `flutter test` before sending code.

## License

Free and open source. See the [LICENSE](LICENSE) file.

---

<div align="center">

Made by **Lumio Apps** · privacy first: offline, no ads, no tracking

</div>
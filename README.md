# Codex Windows Runtime Fix

An unofficial community workaround for a Windows startup issue affecting the
OpenAI Codex / ChatGPT desktop application.

After some application updates, Codex may start background processes but fail
to display its UI. In the affected configuration observed during debugging,
the application repeatedly created incomplete `cua_node` runtime staging
directories instead of successfully finalizing the runtime.

This tool detects that specific failure pattern, reconstructs the finalized
runtime from the copy bundled with the installed application, verifies the
result, and launches the app.

> [!IMPORTANT]
> This is an unofficial community workaround. It is not affiliated with,
> maintained by, or endorsed by OpenAI.

## Symptoms

This workaround may be relevant if:

- Codex / ChatGPT Desktop worked before an application update.
- After updating, the application no longer displays its window.
- `ChatGPT.exe` processes still appear in Task Manager.
- The following directory contains one or more incomplete `.staging-*`
  directories:

```text
%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node
```

For example:

```text
.staging-b63ee7ee40c23b77-xxxxxx
.staging-b63ee7ee40c23b77-yyyyyy
```

while the corresponding finalized directory:

```text
b63ee7ee40c23b77
```

is missing or incomplete.

## What the tool does

The repair script:

1. Stops existing ChatGPT/Codex processes.
2. Detects the currently installed `OpenAI.Codex` Windows package.
3. Locates the `cua_node` runtime bundled with that package.
4. Verifies that the bundled runtime contains:
   - `bin\node.exe`
   - `bin\node_repl.exe`
   - `manifest.json`
5. Detects the runtime ID from the newest `.staging-*` directory.
6. Checks whether the finalized runtime already exists and is complete.
7. If necessary, copies the bundled runtime to the expected local runtime
   directory using `xcopy`.
8. Verifies file count, total byte size, and the critical runtime files.
9. Launches Codex / ChatGPT.

The runtime ID is detected automatically. No application version or runtime
hash is hard-coded.

## Usage

### Option A — One-click launcher

Download both files:

```text
Fix-CodexRuntime.bat
Fix-CodexRuntime.ps1
```

Keep them in the same directory.

Double-click:

```text
Fix-CodexRuntime.bat
```

If Windows displays a UAC prompt, review it and choose whether to continue.

The script will only launch the application automatically after runtime
verification succeeds.

### Option B — Run the PowerShell script directly

Open PowerShell and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Fix-CodexRuntime.ps1"
```

## Privacy

The script itself:

- does **not** connect to the Internet;
- does **not** upload data;
- does **not** collect telemetry;
- does **not** read ChatGPT conversations;
- does **not** access OpenAI account credentials;
- does **not** read browser cookies;
- does **not** inspect arbitrary user documents;
- does **not** delete existing runtime or staging directories.

It operates only on the installed application package and the local
`cua_node` runtime directory required for this workaround.

The normal Codex / ChatGPT application may of course use the network after it
is launched. That behavior is separate from this repair script.

### Sharing diagnostic output

The public-facing script intentionally avoids printing full user-specific
filesystem paths where possible.

Nevertheless, always review terminal output, screenshots, crash dumps, and
application logs before posting them publicly.

Do **not** upload private Codex logs, crash dumps, credentials, or your
`.codex` directory without reviewing their contents first.

## Safety behavior

The script intentionally aborts instead of guessing when:

- `OpenAI.Codex` cannot be found;
- multiple matching packages are detected;
- the bundled runtime is incomplete;
- no `.staging-*` directories exist;
- the staging directory name has an unexpected format;
- `xcopy` fails;
- file counts do not match;
- total byte sizes do not match; or
- critical runtime files are missing after repair.

The script does not automatically delete old runtimes or failed staging
directories.

## Why `xcopy /G`?

The workaround uses:

```text
xcopy /E /I /H /Y /G
```

The `/G` option instructs Windows `xcopy` to allow encrypted source files to
be copied to a destination that does not support encryption.

See Microsoft's `xcopy` documentation for the exact option semantics.

## Limitations

This tool addresses one specific observed failure mode.

A missing UI can have many other causes. If no incomplete `.staging-*`
runtime directories are present, this script intentionally refuses to
perform a repair.

Future versions of the Codex desktop application may change the package
layout or runtime mechanism, in which case this workaround may stop working.

## Tested scenario

The workaround was developed after observing the following pattern on
Windows:

```text
Codex works
    ↓
application update
    ↓
new cua_node runtime ID
    ↓
multiple incomplete .staging-* directories
    ↓
application fails to display its UI
    ↓
reconstruct finalized runtime from bundled cua_node
    ↓
runtime verification succeeds
    ↓
application launches again
```

Because the runtime ID can change between application versions, the script
detects it dynamically rather than hard-coding a known hash.

## Reporting an issue

When reporting a problem, please include:

- Windows version
- installed Codex version
- runtime ID shown by the script
- staging attempt count
- source/runtime file counts
- source/runtime sizes
- the final error message

Please remove any personal information before posting screenshots or logs.

## Disclaimer

Use this workaround at your own risk.

It modifies files in the application's local runtime directory. Although it
performs verification before launching the application and does not
intentionally delete existing runtime data, it is still an unofficial
workaround for application behavior that may change in future releases.

## License

MIT
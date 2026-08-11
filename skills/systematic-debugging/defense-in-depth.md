# Defense-in-Depth Validation

## Overview

When you fix a bug caused by invalid data, adding validation at one place feels sufficient. But that single check can be bypassed by different code paths, refactoring, or mocks.

**Core principle:** Validate at EVERY layer data passes through. Make the bug structurally impossible.

## Why Multiple Layers

Single validation: "We fixed the bug"
Multiple layers: "We made the bug impossible"

Different layers catch different cases:
- Entry validation catches most bugs
- Business logic catches edge cases
- Environment guards prevent context-specific dangers
- Debug logging helps when other layers fail

## The Four Layers

### Layer 1: Entry Point Validation
**Purpose:** Reject obviously invalid input at API boundary

```typescript
function createProject(name: string, workingDirectory: string) {
  if (!workingDirectory || workingDirectory.trim() === '') {
    throw new Error('workingDirectory cannot be empty');
  }
  if (!existsSync(workingDirectory)) {
    throw new Error(`workingDirectory does not exist: ${workingDirectory}`);
  }
  if (!statSync(workingDirectory).isDirectory()) {
    throw new Error(`workingDirectory is not a directory: ${workingDirectory}`);
  }
  // ... proceed
}
```

### Layer 2: Business Logic Validation
**Purpose:** Ensure data makes sense for this operation

```typescript
function initializeWorkspace(projectDir: string, sessionId: string) {
  if (!projectDir) {
    throw new Error('projectDir required for workspace initialization');
  }
  // ... proceed
}
```

### Layer 3: Environment Guards
**Purpose:** Prevent dangerous operations in specific contexts

```typescript
function getWorkspaceTmpDir(): string {
  const result = spawnSync('jj', ['workspace', 'root'], { encoding: 'utf8' });

  if (result.error) {
    if ((result.error as NodeJS.ErrnoException).code !== 'ENOENT') throw result.error;
    return resolve('.tmp');
  }

  if (result.status !== 0) {
    if (/\bno\b.*\b(?:repository|repo)\b/i.test(result.stderr)) return resolve('.tmp');
    throw new Error(`jj workspace root failed: ${result.stderr.trim()}`);
  }

  const root = result.stdout.trim();
  if (!root) throw new Error('jj workspace root returned an empty path');
  return resolve(root, '.tmp');
}

async function jjInit(directory: string) {
  // In tests, refuse repository initialization outside the workspace's .tmp.
  if (process.env.NODE_ENV === 'test') {
    const normalized = normalize(resolve(directory));
    const workspaceTmpDir = normalize(getWorkspaceTmpDir());
    const relativePath = relative(workspaceTmpDir, normalized);

    if (relativePath === '..' || relativePath.startsWith(`..${sep}`) || isAbsolute(relativePath)) {
      throw new Error(
        `Refusing jj git init outside ${workspaceTmpDir} during tests: ${directory}`
      );
    }
  }
  // ... proceed
}
```

### Layer 4: Debug Instrumentation
**Purpose:** Capture context for forensics

```typescript
async function jjInit(directory: string) {
  const stack = new Error().stack;
  logger.debug('About to run jj git init', {
    directory,
    cwd: process.cwd(),
    stack,
  });
  // ... proceed
}
```

## Applying the Pattern

When you find a bug:

1. **Trace the data flow** - Where does bad value originate? Where used?
2. **Map all checkpoints** - List every point data passes through
3. **Add validation at each layer** - Entry, business, environment, debug
4. **Test each layer** - Try to bypass layer 1, verify layer 2 catches it

## Example from Session

Bug: Empty `projectDir` caused `jj git init` in source code

**Data flow:**
1. Test setup → empty string
2. `Project.create(name, '')`
3. `WorkspaceManager.createWorkspace('')`
4. `jj git init` runs in `process.cwd()`

**Four layers added:**
- Layer 1: `Project.create()` validates not empty/exists/writable
- Layer 2: `WorkspaceManager` validates projectDir not empty
- Layer 3: `WorkspaceManager` refuses `jj git init` outside `$(jj workspace root)/.tmp` in tests, with local `.tmp` fallback only when no JJ repository exists or JJ is unavailable
- Layer 4: Stack trace logging before `jj git init`

**Result:** All 1847 tests passed, bug impossible to reproduce

## Key Insight

All four layers were necessary. During testing, each layer caught bugs the others missed:
- Different code paths bypassed entry validation
- Mocks bypassed business logic checks
- Edge cases on different platforms needed environment guards
- Debug logging identified structural misuse

**Don't stop at one validation point.** Add checks at every layer.

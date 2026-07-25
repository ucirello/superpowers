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
async function initJjRepository(directory: string) {
  // In tests, allow repository initialization only in local temporary storage.
  if (process.env.NODE_ENV === 'test') {
    const normalized = normalize(resolve(directory));
    let workspaceRoot: string;
    try {
      workspaceRoot = execFileSync('jj', ['workspace', 'root'], {
        encoding: 'utf8',
      }).trim();
    } catch {
      workspaceRoot = process.cwd();
    }
    const temporaryRoot = normalize(resolve(workspaceRoot, '.tmp', 'rocketclaw'));
    mkdirSync(temporaryRoot, { recursive: true, mode: 0o700 });
    const realTemporaryRoot = realpathSync(temporaryRoot);
    const realParent = realpathSync(dirname(normalized));
    const temporaryPrefix = `${realTemporaryRoot}${sep}`;

    if (realParent !== realTemporaryRoot && !realParent.startsWith(temporaryPrefix)) {
      throw new Error(
        `Refusing jj git init outside ${temporaryRoot} during tests: ${directory}`
      );
    }
  }
  // ... proceed
}
```

### Layer 4: Debug Instrumentation
**Purpose:** Capture context for forensics

```typescript
async function initJjRepository(directory: string) {
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

## Historical Example from Session

The incident is mechanically expressed with Jujutsu commands here; its session
details and results remain historical data from the original case.

Bug: Empty `projectDir` caused `jj git init` in source code

**Data flow:**
1. Test setup → empty string
2. `Project.create(name, '')`
3. `WorkspaceManager.createWorkspace('')`
4. `jj git init` runs in `process.cwd()`

**Four layers added:**
- Layer 1: `Project.create()` validates not empty/exists/writable
- Layer 2: `WorkspaceManager` validates projectDir not empty
- Layer 3: `WorktreeManager` creates `$(jj workspace root)/.tmp/rocketclaw` safely, falls back to `.tmp/rocketclaw`, and refuses `jj git init` elsewhere in tests
- Layer 4: Stack trace logging before `jj git init`

**Result:** All 1847 tests passed, bug impossible to reproduce

## Key Insight

All four layers were necessary. During testing, each layer caught bugs the others missed:
- Different code paths bypassed entry validation
- Mocks bypassed business logic checks
- Edge cases on different platforms needed environment guards
- Debug logging identified structural misuse

**Don't stop at one validation point.** Add checks at every layer.

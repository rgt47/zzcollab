# MCP R Environment Validator - Technical Specification

**Version**: 1.0.0
**Author**: ZZCOLLAB Team
**Date**: 2025-11-15
**Status**: Design Specification

## Executive Summary

The MCP R Environment Validator (`mcp-renv-validator`) is a Model Context Protocol (MCP) server that exposes the functionality of zzcollab's `validate.sh` script to AI assistants. This enables AI coding assistants to proactively manage R package dependencies during code generation, ensuring that every package reference in generated code is automatically validated and synchronized with `DESCRIPTION` and `renv.lock`.

**Key Innovation**: AI assistants gain real-time awareness of R package dependencies, transforming from "code generators that might work" to "reproducibility-aware development partners."

## Problem Statement

### Current State

When AI assistants help users write R code, they face a fundamental disconnect:

```r
# AI generates this code:
library(dplyr)
library(ggplot2)
data %>%
  filter(x > 10) %>%
  ggplot(aes(x, y)) + geom_point()
```

**Problems**:
1. AI has no awareness if `dplyr` or `ggplot2` are in `DESCRIPTION`
2. AI cannot verify if packages are in `renv.lock`
3. User must manually run validation after AI session
4. Reproducibility is an afterthought, not integrated into workflow
5. High friction between "code that runs" and "code that's reproducible"

### Desired State

```r
# AI generates this code:
library(dplyr)    # ✓ Auto-validated, added to DESCRIPTION + renv.lock
library(ggplot2)  # ✓ Auto-validated, added to DESCRIPTION + renv.lock
data %>%
  filter(x > 10) %>%
  ggplot(aes(x, y)) + geom_point()
```

**Benefits**:
1. AI validates every package reference in real-time
2. AI automatically adds missing packages to `DESCRIPTION`
3. AI automatically adds missing packages to `renv.lock`
4. User receives reproducible code by default
5. Zero manual validation steps required

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        AI Assistant                             │
│                   (Claude Desktop, Cursor)                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ MCP Protocol (JSON-RPC)
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                   mcp-renv-validator                            │
│                    (TypeScript Server)                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Tool Registry                                           │  │
│  │  - check_package_available                               │  │
│  │  - validate_dependencies                                 │  │
│  │  - add_package                                           │  │
│  │  - get_package_version                                   │  │
│  │  - extract_packages_from_code                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Shell Interface Layer                                   │  │
│  │  (Executes validate.sh via child_process)                │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Shell Execution
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                      validate.sh                                │
│                   (Pure Shell Script)                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  - Package extraction (grep, awk, sed)                   │  │
│  │  - DESCRIPTION parsing (awk)                             │  │
│  │  - renv.lock parsing (jq)                                │  │
│  │  - CRAN API queries (curl)                               │  │
│  │  - JSON manipulation (jq)                                │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ File I/O
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                    R Project Files                              │
│  - DESCRIPTION                                                  │
│  - renv.lock                                                    │
│  - R/*.R                                                        │
│  - analysis/scripts/*.R                                         │
└─────────────────────────────────────────────────────────────────┘
```

### Technology Stack

- **MCP Server**: TypeScript with `@modelcontextprotocol/sdk`
- **Validation Engine**: `modules/validation.sh` (existing zzcollab script)
- **Shell Execution**: Node.js `child_process.spawn()`
- **Communication**: JSON-RPC over stdio (MCP standard)
- **Package Lookup**: CRAN API (`https://crandb.r-pkg.org/`)

## MCP Server Specification

### Server Metadata

```typescript
{
  name: "mcp-renv-validator",
  version: "1.0.0",
  description: "R package dependency validation and management for AI assistants",
  author: "ZZCOLLAB Team",
  license: "MIT",
  homepage: "https://github.com/rgt47/zzcollab",
  repository: "https://github.com/rgt47/mcp-renv-validator"
}
```

### Tool Definitions

#### 1. check_package_available

**Purpose**: Check if a package is available on CRAN and return metadata.

**Request Schema**:
```typescript
interface CheckPackageRequest {
  name: "check_package_available";
  arguments: {
    package_name: string;      // Package name to check
    repository?: string;       // Optional: "CRAN" (default), "Bioconductor", "GitHub"
  };
}
```

**Response Schema**:
```typescript
interface CheckPackageResponse {
  available: boolean;
  package: string;
  version?: string;           // Latest version if available
  repository?: string;        // Source repository
  dependencies?: string[];    // Direct dependencies
  suggests?: string[];        // Suggested packages
  error?: string;             // Error message if not available
}
```

**Example Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "check_package_available",
    "arguments": {
      "package_name": "dplyr"
    }
  },
  "id": 1
}
```

**Example Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"available\":true,\"package\":\"dplyr\",\"version\":\"1.1.4\",\"repository\":\"CRAN\",\"dependencies\":[\"R\",\"generics\",\"glue\",\"lifecycle\",\"magrittr\",\"methods\",\"pillar\",\"R6\",\"rlang\",\"tibble\",\"tidyselect\",\"utils\",\"vctrs\"]}"
      }
    ]
  },
  "id": 1
}
```

**Implementation**:
```typescript
async function checkPackageAvailable(packageName: string, repository: string = "CRAN"): Promise<CheckPackageResponse> {
  const url = `https://crandb.r-pkg.org/${packageName}`;

  try {
    const response = await fetch(url);

    if (!response.ok) {
      return {
        available: false,
        package: packageName,
        error: `Package '${packageName}' not found on CRAN`
      };
    }

    const data = await response.json();

    return {
      available: true,
      package: packageName,
      version: data.Version,
      repository: "CRAN",
      dependencies: data.Imports ? Object.keys(data.Imports) : [],
      suggests: data.Suggests ? Object.keys(data.Suggests) : []
    };
  } catch (error) {
    return {
      available: false,
      package: packageName,
      error: `Error checking package: ${error.message}`
    };
  }
}
```

#### 2. validate_dependencies

**Purpose**: Validate that all packages used in code are present in `DESCRIPTION` and `renv.lock`.

**Request Schema**:
```typescript
interface ValidateDependenciesRequest {
  name: "validate_dependencies";
  arguments: {
    project_path: string;      // Path to R project root
    strict?: boolean;          // Include tests/ and vignettes/ (default: true)
    auto_fix?: boolean;        // Automatically add missing packages (default: false)
  };
}
```

**Response Schema**:
```typescript
interface ValidateDependenciesResponse {
  valid: boolean;
  missing_from_description: string[];   // Packages used in code but not in DESCRIPTION
  missing_from_renv: string[];          // Packages in DESCRIPTION but not in renv.lock
  unused_in_description: string[];      // Packages in DESCRIPTION but not used in code
  fixed?: boolean;                      // True if auto_fix was enabled and fixes applied
  changes?: {
    description_added: string[];        // Packages added to DESCRIPTION
    renv_added: string[];               // Packages added to renv.lock
  };
  errors?: string[];                    // Validation errors encountered
}
```

**Example Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "validate_dependencies",
    "arguments": {
      "project_path": "/Users/username/projects/myanalysis",
      "strict": true,
      "auto_fix": true
    }
  },
  "id": 2
}
```

**Example Response (with fixes)**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"valid\":false,\"missing_from_description\":[\"dplyr\",\"ggplot2\"],\"missing_from_renv\":[],\"unused_in_description\":[],\"fixed\":true,\"changes\":{\"description_added\":[\"dplyr\",\"ggplot2\"],\"renv_added\":[\"dplyr\",\"ggplot2\"]},\"errors\":[]}"
      }
    ]
  },
  "id": 2
}
```

**Implementation**:
```typescript
async function validateDependencies(
  projectPath: string,
  strict: boolean = true,
  autoFix: boolean = false
): Promise<ValidateDependenciesResponse> {
  const args = ["--verbose"];

  if (autoFix) {
    args.push("--fix");
  } else {
    args.push("--no-fix");
  }

  if (strict) {
    args.push("--strict");
  } else {
    args.push("--no-strict");
  }

  const result = await executeValidateScript(projectPath, args);

  return parseValidationOutput(result);
}

async function executeValidateScript(projectPath: string, args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    const validatePath = path.join(projectPath, "modules", "validation.sh");
    const proc = spawn("bash", [validatePath, ...args], {
      cwd: projectPath,
      env: process.env
    });

    let stdout = "";
    let stderr = "";

    proc.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    proc.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    proc.on("close", (code) => {
      if (code === 0) {
        resolve(stdout);
      } else {
        reject(new Error(`Validation failed (exit code ${code}): ${stderr}`));
      }
    });
  });
}
```

#### 3. add_package

**Purpose**: Add a package to `DESCRIPTION` and `renv.lock` with proper version information.

**Request Schema**:
```typescript
interface AddPackageRequest {
  name: "add_package";
  arguments: {
    project_path: string;      // Path to R project root
    package_name: string;      // Package to add
    version?: string;          // Specific version (default: latest from CRAN)
    type?: string;             // "Imports" (default), "Suggests", "Depends"
  };
}
```

**Response Schema**:
```typescript
interface AddPackageResponse {
  success: boolean;
  package: string;
  version: string;
  added_to_description: boolean;
  added_to_renv: boolean;
  dependencies_added?: string[];   // Transitive dependencies also added
  error?: string;
}
```

**Example Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "add_package",
    "arguments": {
      "project_path": "/Users/username/projects/myanalysis",
      "package_name": "dplyr",
      "type": "Imports"
    }
  },
  "id": 3
}
```

**Example Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"success\":true,\"package\":\"dplyr\",\"version\":\"1.1.4\",\"added_to_description\":true,\"added_to_renv\":true,\"dependencies_added\":[\"tibble\",\"tidyselect\",\"vctrs\"]}"
      }
    ]
  },
  "id": 3
}
```

**Implementation**:
```typescript
async function addPackage(
  projectPath: string,
  packageName: string,
  version?: string,
  type: string = "Imports"
): Promise<AddPackageResponse> {
  // 1. Check if package exists on CRAN
  const packageInfo = await checkPackageAvailable(packageName);

  if (!packageInfo.available) {
    return {
      success: false,
      package: packageName,
      version: "",
      added_to_description: false,
      added_to_renv: false,
      error: `Package '${packageName}' not found on CRAN`
    };
  }

  const targetVersion = version || packageInfo.version!;

  // 2. Add to DESCRIPTION
  const descriptionAdded = await addToDescription(
    projectPath,
    packageName,
    type
  );

  // 3. Add to renv.lock
  const renvAdded = await addToRenvLock(
    projectPath,
    packageName,
    targetVersion
  );

  // 4. Validate
  const validation = await validateDependencies(projectPath, true, false);

  return {
    success: descriptionAdded && renvAdded,
    package: packageName,
    version: targetVersion,
    added_to_description: descriptionAdded,
    added_to_renv: renvAdded,
    dependencies_added: packageInfo.dependencies
  };
}
```

#### 4. get_package_version

**Purpose**: Get the current version of a package in `renv.lock` or latest version on CRAN.

**Request Schema**:
```typescript
interface GetPackageVersionRequest {
  name: "get_package_version";
  arguments: {
    package_name: string;
    project_path?: string;     // If provided, check renv.lock first
    source?: string;           // "renv" (check renv.lock), "cran" (check CRAN)
  };
}
```

**Response Schema**:
```typescript
interface GetPackageVersionResponse {
  package: string;
  version?: string;
  source: string;              // "renv.lock", "CRAN", "not_found"
  latest_version?: string;     // Latest version on CRAN
  update_available?: boolean;  // True if renv version < CRAN version
  error?: string;
}
```

#### 5. extract_packages_from_code

**Purpose**: Extract all package references from R code without modifying any files.

**Request Schema**:
```typescript
interface ExtractPackagesRequest {
  name: "extract_packages_from_code";
  arguments: {
    code?: string;             // R code to analyze (optional)
    file_path?: string;        // Path to R file to analyze (optional)
    project_path?: string;     // Path to R project (analyzes all .R files)
  };
}
```

**Response Schema**:
```typescript
interface ExtractPackagesResponse {
  packages: string[];
  sources: {
    library_calls: string[];    // From library(pkg)
    require_calls: string[];    // From require(pkg)
    namespace_calls: string[];  // From pkg::function()
  };
  files?: string[];             // Files analyzed (if project_path provided)
}
```

**Example Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "extract_packages_from_code",
    "arguments": {
      "code": "library(dplyr)\nlibrary(ggplot2)\ndata %>% tidyr::pivot_longer(cols)"
    }
  },
  "id": 4
}
```

**Example Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"packages\":[\"dplyr\",\"ggplot2\",\"tidyr\"],\"sources\":{\"library_calls\":[\"dplyr\",\"ggplot2\"],\"require_calls\":[],\"namespace_calls\":[\"tidyr\"]}}"
      }
    ]
  },
  "id": 4
}
```

## Integration Patterns

### Pattern 1: Proactive Validation During Code Generation

**Workflow**:
1. AI assistant generates R code with package usage
2. AI automatically calls `extract_packages_from_code` on generated code
3. AI calls `validate_dependencies` to check consistency
4. If inconsistencies found, AI calls `add_package` for each missing package
5. AI informs user: "Added dplyr (1.1.4) and ggplot2 (3.4.4) to DESCRIPTION and renv.lock"

**Example Conversation**:

```
User: "Write a function to summarize data by group"

AI: Here's a function that summarizes data by group using dplyr:

```r
summarize_by_group <- function(data, group_var, summary_var) {
  library(dplyr)

  data %>%
    group_by({{group_var}}) %>%
    summarise(
      n = n(),
      mean = mean({{summary_var}}, na.rm = TRUE),
      sd = sd({{summary_var}}, na.rm = TRUE)
    )
}
```

[AI internally calls extract_packages_from_code]
[AI internally calls validate_dependencies with auto_fix = true]

AI: ✓ Added dplyr (1.1.4) to DESCRIPTION and renv.lock

User: Great! Now add a visualization

AI: Here's an enhanced version with visualization:

```r
summarize_and_plot <- function(data, group_var, summary_var) {
  library(dplyr)
  library(ggplot2)

  summary <- data %>%
    group_by({{group_var}}) %>%
    summarise(
      n = n(),
      mean = mean({{summary_var}}, na.rm = TRUE),
      sd = sd({{summary_var}}, na.rm = TRUE)
    )

  plot <- ggplot(summary, aes(x = {{group_var}}, y = mean)) +
    geom_col() +
    geom_errorbar(aes(ymin = mean - sd, ymax = mean + sd), width = 0.2) +
    theme_minimal()

  list(summary = summary, plot = plot)
}
```

[AI internally detects new package ggplot2]
[AI internally calls add_package for ggplot2]

AI: ✓ Added ggplot2 (3.4.4) to DESCRIPTION and renv.lock
```

**Benefits**:
- User never needs to think about dependency management
- DESCRIPTION and renv.lock always in sync with code
- Reproducibility maintained automatically
- No post-session cleanup required

### Pattern 2: Refactoring Assistance

**Workflow**:
1. User asks AI to refactor code to use different packages
2. AI generates new code
3. AI extracts new package dependencies
4. AI validates and adds new packages
5. AI identifies packages that are no longer used
6. AI suggests removing unused packages from DESCRIPTION

**Example**:

```
User: "Refactor this to use data.table instead of dplyr"

AI: Here's the refactored version using data.table:

```r
library(data.table)

summarize_by_group <- function(data, group_var, summary_var) {
  dt <- as.data.table(data)
  dt[, .(
    n = .N,
    mean = mean(get(summary_var), na.rm = TRUE),
    sd = sd(get(summary_var), na.rm = TRUE)
  ), by = group_var]
}
```

[AI calls extract_packages_from_code → finds data.table]
[AI calls validate_dependencies → dplyr still in DESCRIPTION]
[AI calls add_package for data.table]

AI: ✓ Added data.table (1.14.8) to DESCRIPTION and renv.lock
AI: ℹ️  Note: dplyr is still in DESCRIPTION but no longer used in this file. Run `make check-renv` on the full project to identify unused packages.
```

### Pattern 3: Learning Mode

**Workflow**:
1. User asks "what packages do I need for X?"
2. AI uses `check_package_available` to verify packages exist
3. AI provides educational response with package purposes
4. If user proceeds, AI adds packages proactively

**Example**:

```
User: "What packages do I need for spatial analysis?"

AI: For spatial analysis in R, here are the key packages:

[AI calls check_package_available for each package]

1. **sf** (1.0-14) - Simple Features for R, handles vector spatial data
2. **terra** (1.7-55) - Spatial data analysis with rasters and vectors
3. **sp** (2.1-1) - Older but still widely used spatial data classes
4. **raster** (3.6-26) - Raster data analysis (consider terra for new projects)

Would you like me to add these to your project?

User: Yes, add sf and terra

[AI calls add_package for sf and terra]

AI: ✓ Added sf (1.0-14) to DESCRIPTION and renv.lock
    Dependencies also added: units (0.8-4), classInt (0.4-10), DBI (1.1.3)
AI: ✓ Added terra (1.7-55) to DESCRIPTION and renv.lock
    Dependencies also added: Rcpp (1.0.11)

Your project is now configured for spatial analysis with modern tools.
```

## Deployment

### Installation

**Prerequisites**:
- Node.js >= 18.0.0
- npm >= 9.0.0
- zzcollab project structure (with `modules/validation.sh`)

**MCP Server Installation**:

```bash
# Clone repository
git clone https://github.com/rgt47/mcp-renv-validator.git
cd mcp-renv-validator

# Install dependencies
npm install

# Build TypeScript
npm run build

# Link globally for CLI access
npm link
```

### Configuration

**Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "renv-validator": {
      "command": "node",
      "args": [
        "/path/to/mcp-renv-validator/build/index.js"
      ],
      "env": {
        "ZZCOLLAB_VALIDATION_STRICT": "true",
        "ZZCOLLAB_AUTO_FIX": "false"
      }
    }
  }
}
```

**Cursor** (`.cursor/mcp.json` in project root):

```json
{
  "mcpServers": {
    "renv-validator": {
      "command": "node",
      "args": [
        "/path/to/mcp-renv-validator/build/index.js"
      ],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

**VS Code with Continue** (`.continue/config.json`):

```json
{
  "experimental": {
    "modelContextProtocol": true
  },
  "mcpServers": {
    "renv-validator": {
      "command": "node",
      "args": [
        "/path/to/mcp-renv-validator/build/index.js"
      ]
    }
  }
}
```

### Environment Variables

- **`ZZCOLLAB_VALIDATION_STRICT`** (default: `true`): Include tests/ and vignettes/ in validation
- **`ZZCOLLAB_AUTO_FIX`** (default: `false`): Automatically add missing packages
- **`ZZCOLLAB_PROJECT_PATH`** (optional): Default project path for validation
- **`CRAN_MIRROR`** (default: `https://crandb.r-pkg.org/`): CRAN API endpoint

## Testing

### Unit Tests

```bash
npm test
```

**Test Coverage**:
- Tool request/response parsing
- Shell script execution
- Error handling
- Package extraction logic
- CRAN API mocking
- File I/O operations

### Integration Tests

```bash
npm run test:integration
```

**Scenarios Tested**:
1. Fresh project initialization
2. Adding first package to empty DESCRIPTION
3. Detecting packages from existing code
4. Handling missing packages on CRAN
5. Concurrent package additions
6. Large project validation (100+ packages)

### End-to-End Tests with AI Assistant

**Test with Claude Desktop**:

```bash
# Start Claude Desktop with MCP server configured
# Try these prompts:

1. "Write a dplyr pipeline to filter and summarize data"
   Expected: AI generates code + auto-adds dplyr

2. "Add a ggplot2 visualization"
   Expected: AI adds code + auto-adds ggplot2

3. "What packages am I using in this project?"
   Expected: AI calls extract_packages_from_code and lists them

4. "Check if my dependencies are in sync"
   Expected: AI calls validate_dependencies and reports status
```

## Implementation Roadmap

### Phase 1: Core Functionality (Weeks 1-2)

- [x] Set up TypeScript project with MCP SDK
- [ ] Implement `check_package_available` tool
- [ ] Implement `extract_packages_from_code` tool
- [ ] Implement shell execution layer for `validation.sh`
- [ ] Write unit tests for core tools
- [ ] Create basic CLI for testing

### Phase 2: Validation Integration (Weeks 3-4)

- [ ] Implement `validate_dependencies` tool
- [ ] Parse validation.sh output
- [ ] Handle auto-fix mode
- [ ] Implement error handling for edge cases
- [ ] Add integration tests with real R projects

### Phase 3: Package Management (Weeks 5-6)

- [ ] Implement `add_package` tool
- [ ] Implement `get_package_version` tool
- [ ] Add support for Bioconductor packages
- [ ] Add support for GitHub packages via remotes
- [ ] Handle transitive dependencies

### Phase 4: AI Assistant Integration (Weeks 7-8)

- [ ] Test with Claude Desktop
- [ ] Test with Cursor
- [ ] Test with VS Code + Continue
- [ ] Document integration patterns
- [ ] Create example prompts and workflows

### Phase 5: Polish and Distribution (Weeks 9-10)

- [ ] Comprehensive documentation
- [ ] Example projects
- [ ] Video tutorials
- [ ] npm package publication
- [ ] MCP registry submission
- [ ] Community feedback integration

## Success Metrics

### Technical Metrics

1. **Accuracy**: >99% correct package extraction from R code
2. **Reliability**: <1% false positives in package filtering
3. **Performance**: Validation completes <2 seconds for projects with <100 packages
4. **Coverage**: Handles 100% of CRAN packages, 95% of Bioconductor packages

### User Experience Metrics

1. **Adoption**: >100 active users within 3 months
2. **Satisfaction**: >4.5/5 stars in user surveys
3. **Time Savings**: Users report 80% reduction in dependency management time
4. **Error Reduction**: 90% fewer "package not found" errors in reproducible workflows

### Ecosystem Impact

1. **Integration**: Support for 3+ AI assistants (Claude, Cursor, Continue)
2. **Community**: 10+ community-contributed improvements
3. **Documentation**: 95% of users can configure without support
4. **Reproducibility**: Measurable increase in R project reproducibility

## Security Considerations

### Shell Injection Prevention

**Risk**: Malicious package names could inject shell commands

**Mitigation**:
```typescript
function sanitizePackageName(name: string): string {
  // Only allow alphanumeric, dots, and underscores (valid R package names)
  if (!/^[a-zA-Z][a-zA-Z0-9.]*$/.test(name)) {
    throw new Error(`Invalid package name: ${name}`);
  }
  return name;
}
```

### File System Access

**Risk**: Path traversal attacks via project_path parameter

**Mitigation**:
```typescript
function validateProjectPath(path: string): string {
  const resolved = fs.realpathSync(path);

  // Ensure path exists and contains DESCRIPTION file
  if (!fs.existsSync(path.join(resolved, "DESCRIPTION"))) {
    throw new Error("Invalid R project: DESCRIPTION not found");
  }

  return resolved;
}
```

### CRAN API Rate Limiting

**Risk**: Excessive API calls could trigger rate limiting

**Mitigation**:
- Implement local cache with 24-hour TTL
- Batch API requests when possible
- Respect HTTP 429 responses with exponential backoff

## Future Enhancements

### V2.0: Advanced Features

1. **Dependency Graph Visualization**: Generate visual dependency trees
2. **Version Conflict Detection**: Identify incompatible package versions
3. **Upgrade Suggestions**: Recommend package updates with changelogs
4. **Reproducibility Score**: Quantify project reproducibility (0-100%)

### V3.0: Multi-Language Support

1. **Python** via `pyproject.toml` and `requirements.txt`
2. **Julia** via `Project.toml` and `Manifest.toml`
3. **Multi-language projects**: R + Python + Julia in single project

### V4.0: Cloud Integration

1. **Docker Image Building**: Auto-generate Dockerfiles from dependencies
2. **CI/CD Integration**: GitHub Actions workflow generation
3. **Package Caching**: Shared package cache across projects
4. **Team Collaboration**: Shared dependency manifests with conflict resolution

## Conclusion

The MCP R Environment Validator bridges the gap between AI code generation and reproducible research practices. By exposing zzcollab's validation capabilities through the Model Context Protocol, AI assistants gain real-time awareness of R package dependencies, transforming reproducibility from an afterthought into an integrated part of the development workflow.

**Key Innovation**: AI assistants become reproducibility partners, not just code generators.

**Impact**: Users receive reproducible code by default, with zero additional effort.

**Future**: This pattern can extend to other languages and dependency systems, establishing a new standard for AI-assisted reproducible research.

## References

- **Model Context Protocol**: https://modelcontextprotocol.io/
- **ZZCOLLAB**: https://github.com/rgt47/zzcollab
- **CRAN API**: https://crandb.r-pkg.org/
- **renv**: https://rstudio.github.io/renv/
- **Claude Desktop**: https://claude.ai/desktop
- **Cursor**: https://cursor.sh/
- **Continue**: https://continue.dev/

## Appendix A: Complete API Reference

### Server Initialization

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new Server(
  {
    name: "mcp-renv-validator",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Register tools
server.setRequestHandler("tools/list", async () => ({
  tools: [
    {
      name: "check_package_available",
      description: "Check if an R package is available on CRAN",
      inputSchema: {
        type: "object",
        properties: {
          package_name: { type: "string" },
          repository: { type: "string", enum: ["CRAN", "Bioconductor", "GitHub"] }
        },
        required: ["package_name"]
      }
    },
    {
      name: "validate_dependencies",
      description: "Validate R package dependencies across DESCRIPTION and renv.lock",
      inputSchema: {
        type: "object",
        properties: {
          project_path: { type: "string" },
          strict: { type: "boolean" },
          auto_fix: { type: "boolean" }
        },
        required: ["project_path"]
      }
    },
    {
      name: "add_package",
      description: "Add R package to DESCRIPTION and renv.lock",
      inputSchema: {
        type: "object",
        properties: {
          project_path: { type: "string" },
          package_name: { type: "string" },
          version: { type: "string" },
          type: { type: "string", enum: ["Imports", "Suggests", "Depends"] }
        },
        required: ["project_path", "package_name"]
      }
    },
    {
      name: "get_package_version",
      description: "Get R package version from renv.lock or CRAN",
      inputSchema: {
        type: "object",
        properties: {
          package_name: { type: "string" },
          project_path: { type: "string" },
          source: { type: "string", enum: ["renv", "cran"] }
        },
        required: ["package_name"]
      }
    },
    {
      name: "extract_packages_from_code",
      description: "Extract R package references from code",
      inputSchema: {
        type: "object",
        properties: {
          code: { type: "string" },
          file_path: { type: "string" },
          project_path: { type: "string" }
        }
      }
    }
  ]
}));

// Start server
const transport = new StdioServerTransport();
await server.connect(transport);
```

## Appendix B: Example Projects

### Minimal Example

```
minimal-example/
├── DESCRIPTION
├── renv.lock
├── modules/
│   └── validation.sh
└── analysis/
    └── scripts/
        └── explore.R
```

**explore.R**:
```r
library(dplyr)
library(ggplot2)

mtcars %>%
  ggplot(aes(x = mpg, y = hp)) +
  geom_point()
```

**AI Session**:
```
User: "Check my dependencies"

[AI calls validate_dependencies]

AI: Your project uses 2 packages:
- dplyr (1.1.4) ✓
- ggplot2 (3.4.4) ✓

All dependencies are properly declared in DESCRIPTION and renv.lock.
```

### Complex Example

See `/Users/zenn/Dropbox/prj/d07/zzcollab/examples/mcp-integration/` for complete working example with:
- Multiple analysis scripts
- Custom functions in R/
- Tests in tests/testthat/
- Vignettes with complex dependencies
- Full MCP integration demonstration

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-15
**Status**: Ready for Implementation
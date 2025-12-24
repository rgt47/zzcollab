# Bash Scripting Standards for ZZCOLLAB

This document defines the coding standards and documentation format for all bash scripts in the ZZCOLLAB project.

## Function Documentation Standard

All functions must follow this documentation format:

```bash
##############################################################################
# FUNCTION: function_name
# PURPOSE:  Brief description of what the function does
# USAGE:    function_name arg1 arg2 [optional_arg]
# ARGS:     
#   $1 - Description of first argument
#   $2 - Description of second argument  
#   $3 - (optional) Description of optional argument
# RETURNS:  
#   0 - Success
#   1 - Error condition description
# GLOBALS:  
#   READ:  Variable names that are read
#   WRITE: Variable names that are modified
# EXAMPLE:
#   function_name "value1" "value2"
#   if function_name "test"; then
#       echo "Success"
#   fi
##############################################################################
```

### Documentation Requirements

1. **FUNCTION**: Exact function name
2. **PURPOSE**: One-line description of the function's purpose
3. **USAGE**: How to call the function with argument placeholders
4. **ARGS**: Description of each argument (mark optional args)
5. **RETURNS**: Exit codes and their meanings
6. **GLOBALS**: Variables read from or written to global scope
7. **EXAMPLE**: Practical usage examples

### Additional Standards

- Use consistent spacing and alignment
- Keep PURPOSE to one line, expand in description below if needed
- Mark optional arguments with `(optional)` prefix
- List all possible return codes
- Include realistic examples
- Use proper case for section headers

## Code Style Standards

### Variable Naming
- Use lowercase with underscores: `my_variable`
- Constants in UPPERCASE: `MY_CONSTANT`
- Use descriptive names: `user_input` not `ui`

### Function Naming
- Use verb-noun pattern: `validate_input`, `create_file`
- Use underscores for separation: `build_docker_image`
- Be descriptive: `check_prerequisites` not `check_prereqs`

### Error Handling
- Always check return codes for critical operations
- Use meaningful error messages
- Include troubleshooting hints in error messages
- Use consistent error message format

### Comments
- Use `#` for single-line comments
- Use `##############################################################################` for section headers
- Document complex logic inline
- Explain WHY, not just WHAT

## Best Practices

1. **Strict Mode**: Always use `set -euo pipefail`
2. **Local Variables**: Use `local` in all functions
3. **Quoting**: Quote all variable references
4. **Parameter Expansion**: Use `${var}` syntax
5. **Arrays**: Use proper array syntax `"${array[@]}"`
6. **Readonly**: Mark constants as `readonly`
7. **Functions**: Break code into logical functions
8. **Validation**: Validate all inputs and prerequisites

## Example Function

```bash
##############################################################################
# FUNCTION: safe_copy_file
# PURPOSE:  Safely copy a file with error handling and logging
# USAGE:    safe_copy_file source_file destination_file [description]
# ARGS:     
#   $1 - Source file path (must exist and be readable)
#   $2 - Destination file path
#   $3 - (optional) Description for logging (defaults to "file")
# RETURNS:  
#   0 - File copied successfully
#   1 - Source file not found or not readable
#   2 - Copy operation failed
# GLOBALS:  
#   READ:  None
#   WRITE: None (uses logging functions)
# EXAMPLE:
#   safe_copy_file "/tmp/source.txt" "/tmp/dest.txt" "configuration file"
#   if safe_copy_file "$config" "$backup_config"; then
#       log_success "Backup created"
#   fi
##############################################################################
safe_copy_file() {
    local source="$1"
    local destination="$2"
    local description="${3:-file}"
    
    # Validate source file exists and is readable
    if [[ ! -f "$source" ]] || [[ ! -r "$source" ]]; then
        log_error "Source $description not found or not readable: $source"
        return 1
    fi
    
    # Attempt to copy file
    if cp "$source" "$destination" 2>/dev/null; then
        log_success "Copied $description: $source → $destination"
        return 0
    else
        log_error "Failed to copy $description: $source → $destination"
        return 2
    fi
}
```

This example demonstrates all the required documentation elements and follows the coding standards.
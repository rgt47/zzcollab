#!/bin/bash
# Wrap Dockerfile lines at 76 characters while preserving syntax

file="$1"
temp=$(mktemp)

# Process the file
awk '
BEGIN { max_len = 76 }

# Comment lines - wrap at 76
/^#/ {
    if (length($0) <= max_len) {
        print
    } else {
        # Wrap comment lines
        line = $0
        while (length(line) > max_len) {
            # Find last space before max_len
            split_pos = max_len
            while (split_pos > 0 && substr(line, split_pos, 1) != " ") {
                split_pos--
            }
            if (split_pos == 0) split_pos = max_len
            
            print substr(line, 1, split_pos)
            line = "#" substr(line, split_pos + 1)
        }
        if (length(line) > 0) print line
    }
    next
}

# RUN commands with backslashes - preserve structure
/^RUN/ && /\\$/ {
    print
    next
}

# Other lines with backslashes - preserve
/\\$/ {
    print
    next
}

# Long single lines without backslashes - add continuation
length($0) > max_len && !/\\$/ {
    print $0 " \\"
    next
}

# All other lines
{
    print
}
' "$file" > "$temp"

# Replace original
mv "$temp" "$file"
echo "Wrapped $file"

BEGIN {
    depth = 0
    skipDepth = -1
}

{
    line = $0

    if (skipDepth < 0 && line ~ /@(font-face|property|keyframes)/) {
        skipDepth = depth
    }

    if (skipDepth < 0 &&
        line ~ /^[[:space:]]*(--)?[a-zA-Z-]+[[:space:]]*:[^;{}]*;[[:space:]]*$/ &&
        line !~ /!important/) {
        sub(/;[[:space:]]*$/, " !important;", line)
    }

    print line

    counted = $0
    depth += gsub(/\{/, "{", counted)
    counted = $0
    depth -= gsub(/\}/, "}", counted)

    if (skipDepth >= 0 && depth <= skipDepth) {
        skipDepth = -1
    }
}

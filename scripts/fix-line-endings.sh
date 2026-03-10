#!/bin/bash
# fix-line-endings.sh
# 清理项目中脚本和配置文件的 Windows 行尾(CRLF)及 BOM 字符
# 在 Linux 上运行，防止跨平台编辑导致的配置损坏

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 需要处理的文件扩展名
EXTENSIONS="sh yml yaml conf json env"

# 统计
fixed=0
skipped=0

fix_file() {
    local file="$1"

    # 检测是否含有 CR 或 BOM
    local has_cr has_bom
    has_cr=$(grep -cP '\r' "$file" 2>/dev/null || true)
    has_bom=$(grep -cP '^\xEF\xBB\xBF' "$file" 2>/dev/null || true)

    if [[ "$has_cr" -eq 0 && "$has_bom" -eq 0 ]]; then
        skipped=$((skipped + 1))
        return
    fi

    local tmp
    tmp=$(mktemp)

    # 去除 BOM (UTF-8 BOM: EF BB BF) 和 CRLF
    sed 's/\r$//' "$file" | sed '1s/^\xEF\xBB\xBF//' > "$tmp"
    mv "$tmp" "$file"

    local changes=""
    [[ "$has_cr"  -gt 0 ]] && changes+="CRLF→LF "
    [[ "$has_bom" -gt 0 ]] && changes+="BOM removed"
    echo "  fixed: ${file#$PROJECT_ROOT/}  ($changes)"
    fixed=$((fixed + 1))
}

echo "=== fix-line-endings.sh ==="
echo "Project root: $PROJECT_ROOT"
echo ""

for ext in $EXTENSIONS; do
    while IFS= read -r -d '' file; do
        # 跳过二进制文件和 images/ 目录
        case "$file" in
            */images/*) continue ;;
            *.tar)      continue ;;
        esac
        fix_file "$file"
    done < <(find "$PROJECT_ROOT" -type f -name "*.${ext}" -print0)
done

# 额外处理无扩展名但在 scripts/ 下的脚本
while IFS= read -r -d '' file; do
    if file "$file" | grep -qE 'text|script'; then
        fix_file "$file"
    fi
done < <(find "$PROJECT_ROOT/scripts" -type f ! -name "*.*" -print0)

echo ""
echo "Done. Fixed: $fixed file(s), Already clean: $skipped file(s)."

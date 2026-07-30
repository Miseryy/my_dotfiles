#!/usr/bin/env bash
set -euo pipefail

MIN_PERCENT=10
CONFIG="${NIRI_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl}"

GAP="$(
    sed -nE \
        's/^[[:space:]]*gaps[[:space:]]+([0-9]+([.][0-9]+)?).*$/\1/p' \
        "$CONFIG" |
    head -n1
)"

[[ -n "$GAP" ]] || die "config.kdlからgapsを取得できません"

die() {
    printf 'fit-right-column: %s\n' "$1" >&2
    exit 1
}

command -v jq >/dev/null || die "jqが必要です"

windows="$(niri msg --json windows)"

focused="$(
    jq -cer '
        first(.[] | select(
            .is_focused == true
            and .is_floating == false
            and .layout.pos_in_scrolling_layout != null
        ))
    ' <<<"$windows"
)" || die "タイルウィンドウがフォーカスされていません"

focused_id="$(jq -r '.id' <<<"$focused")"
workspace_id="$(jq -r '.workspace_id' <<<"$focused")"
column_index="$(jq -r '.layout.pos_in_scrolling_layout[0]' <<<"$focused")"
focused_width="$(jq -r '.layout.tile_size[0]' <<<"$focused")"

next_column=$((column_index + 1))

right_id="$(
    jq -er \
        --argjson workspace_id "$workspace_id" \
        --argjson column "$next_column" '
        first(.[] | select(
            .workspace_id == $workspace_id
            and .is_floating == false
            and .layout.pos_in_scrolling_layout != null
            and .layout.pos_in_scrolling_layout[0] == $column
        )) | .id
    ' <<<"$windows"
)" || die "右隣に列がありません"

output_width="$(
    niri msg --json focused-output |
        jq -er '.logical.width'
)" || die "画面幅を取得できません"

target_percent="$(
    awk -v screen="$output_width" \
        -v left="$focused_width" \
        -v gap="$GAP" '
        BEGIN {
            printf "%.3f", ((screen - left - 2 * gap) / (screen - gap)) * 100
        }
    '
)"

awk -v value="$target_percent" -v min="$MIN_PERCENT" '
    BEGIN { exit !(value >= min) }
' || die "左列が大きすぎます（右列 ${target_percent}%）"

printf '左幅=%spx 画面=%spx 右幅=%s%%\n' \
    "$focused_width" "$output_width" "$target_percent"

niri msg action set-window-width --id "$right_id" "${target_percent}%" >/dev/null

# niri msg action focus-window --id "$right_id" >/dev/null
# niri msg action set-column-width "${target_percent}%" >/dev/null
# niri msg action focus-window --id "$focused_id" >/dev/null
# niri msg action center-visible-columns >/dev/null

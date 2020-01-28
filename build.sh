#!/usr/bin/env bash

set -e

BASE_DIR="$(dirname "$0")"

SRC_DIR="${SRC_DIR:-$BASE_DIR/src}"
BUILD_DIR="${OUT_DIR:-$BASE_DIR/build}"
ALIASES="${ALIASES:-$BASE_DIR/src/cursorList}"

DEFAULT_COLOR="#d64933"
DEFAULT_BG_COLOR="#e8e8e8"
DEFAULT_BORDER_COLOR="#2d2d2d"
DEFAULT_PAGE_COLOR="#ffffff"

COLOR="${COLOR:-$DEFAULT_COLOR}"
BG_COLOR="${BG_COLOR:-$DEFAULT_BG_COLOR}"
BORDER_COLOR="${BORDER_COLOR:-$DEFAULT_BORDER_COLOR}"
PAGE_COLOR="${PAGE_COLOR:-$DEFAULT_PAGE_COLOR}"


validate_hexcolor() {
    local color="$1"
    if ! [[ $color =~ ^#[0-9A-Fa-f]{6}$ ]]; then
        echo -e \
            "Error! The color: $color is an invalid hex value.\n" \
            "\rBe sure to use valid hex values with six digits and prefix (e.g. #000000)."
        exit 1
    fi
}


validate_hexcolor $COLOR
validate_hexcolor $BG_COLOR
validate_hexcolor $BORDER_COLOR
validate_hexcolor $PAGE_COLOR


change_svg_color() {
    local src_dir="$1"

    local args
    gen_args() {
        echo -e "> find all .svg files under $src_dir ..."
        for file in "$src_dir"/*.svg; do
            [ -f "$file" ] || continue
            args="${args}$file\t"
        done
    }
    gen_args

    local re_color="$([ "$DEFAULT_COLOR" == "$COLOR" ] ||
        echo "s/([^\x0])$DEFAULT_COLOR([^\x0])/\1\x0$COLOR\x0\2/g;")"
    local re_bg_color="$([ "$DEFAULT_BG_COLOR" == "$BG_COLOR" ] ||
        echo "s/([^\x0])$DEFAULT_BG_COLOR([^\x0])/\1\x0$BG_COLOR\x0\2/g;")"
    local re_border_color="$([ "$DEFAULT_BORDER_COLOR" == "$BORDER_COLOR" ] ||
        echo "s/([^\x0])$DEFAULT_BORDER_COLOR([^\x0])/\1\x0$BORDER_COLOR\x0\2/g;")"
    local re_clean="s/\x0//g"
    local cmd=$(printf 'sed -i -E "%s %s %s %s" "$0"' $re_color $re_bg_color $re_border_color $re_clean)
    echo "> command: $cmd"
    printf "$args" | xargs -r -d '\t' -n 1 -P "$(nproc)" sh -c "$cmd"
    echo -e "Changing color... DONE"
}


convert_svg_to_png() {
    local src_dir="$1"
    local out_dir="$2"
    local sizes="24 32 48"

    [ -d "$src_dir" ] || exit 1
    [ -d "$out_dir" ] || mkdir -p "$out_dir"

    local args
    gen_args() {
        for file in "$src_dir"/*.svg; do
            [ -f "$file" ] || continue
            for size in $sizes; do
                bitmap_file="${out_dir%/}/$(basename "$file" .svg)_${size}.png"
                args="${args}$bitmap_file\t$size\t$file\t"
            done
        done
    }
    gen_args
    printf "$args" | xargs -r -d '\t' -n 3 -P "$(nproc)" sh -c 'inkscape --without-gui --export-png "$0" -w $1 -h $1 "$2"'

    echo -e "Converting svg to png... DONE"
}


convert_to_x11cursor() {
    local src_dir="$1"
    local config_dir="$2"
    local out_dir="$3"

    [ -d "$src_dir" ] || exit 1
    [ -d "$out_dir" ] && rm -rf "$out_dir"
    mkdir -p "$out_dir"

    for config in "$2"/*.cursor; do
        [ -f "$config" ] || continue
        base_name="$(basename "$config" .cursor)"
        xcursorgen -p "$src_dir" "$config" "$out_dir/$base_name"
    done

    echo -e "Generating cursor theme... DONE"
}



create_aliases() {
    local out_dir="$1"
    local symlink target

    echo -ne "Generating shortcuts...\\r"
    while read -r symlink target; do
        [ -e "$out_dir/$symlink" ] && continue
        ln -sf "$target" "$out_dir/$symlink"
    done < "$ALIASES"
    echo -e "Generating shortcuts... DONE"
}


[ -d "$BUILD_DIR" ] && rm -rf "$BUILD_DIR"

# copy all source files because we may edit it (change color...).
mkdir -p $BUILD_DIR && cp -r $SRC_DIR/numix_cursor $SRC_DIR/config $BUILD_DIR/

change_svg_color "$BUILD_DIR/numix_cursor"
convert_svg_to_png "$BUILD_DIR/numix_cursor" "$BUILD_DIR/build"
convert_to_x11cursor "$BUILD_DIR/build" "$BUILD_DIR/config" "$BUILD_DIR/cursors"
create_aliases "$BUILD_DIR/cursors"

[ -d "$BUILD_DIR"/dist ] && rm -rf "$BUILD_DIR"/dist
mkdir -p "$BUILD_DIR"/dist
cp -r "$BUILD_DIR/cursors" "$BUILD_DIR"/dist/
cp "$SRC_DIR/cursor.theme" "$SRC_DIR/index.theme" "$BUILD_DIR"/dist/

# nest-dolphin installer
# Licensed under the GNU GPL 3.0

# to preserve newlines, gets written into $ENTRY_DESKTOP_FILE
read -r -d '' ENTRY_DESKTOP_FILE <<'EOF'
[Desktop Entry]
Type=Service
MimeType=image/*;video/*;audio/*;text/*;
Actions=uploadToNest;

[Desktop Action uploadToNest]
Name=Upload to nest.rip
Icon=upload-media
Comment=Upload selected files to nest.rip
Exec=~/.local/bin/nest-dolphin %f
EOF

# preserve newlines
printf '%s' "$ENTRY_DESKTOP_FILE" > /tmp/nest-dolphin.desktop

BIN_CONTAINING_DIR="$HOME/.local/bin"

if [ -e "${BIN_CONTAINING_DIR}" ]; then
    :
else
    echo "Creating $BIN_CONTAINING_DIR, if not on path it will have to be added."
    mkdir -p "$BIN_CONTAINING_DIR"
fi

mkdir -p /tmp

# first arg is variable name to store into
# https://develop.kde.org/docs/apps/dolphin/service-menus/#where-the-servicemenus-are-located
get_svcmenu_dir() {
    DEFAULT_DIR_0="/usr/share/kio/servicemenus"
    DEFAULT_DIR_1="~/.local/share/kio/servicemenus"

    # if unset or empty, allows user to specify with the SERVICE_MENU_DIR environment variable
    if [ -z "${SERVICE_MENU_DIR}" ]; then
        # get output or empty string
        QT_LOCATED_DIRS="$(qtpaths --locate-dirs GenericDataLocation kio/servicemenus 2> /dev/null || printf '')"
        if [ -z "${QT_LOCATED_DIRS}" ]; then
            : # couldn't get from qt, so pass out of this if/else bc i dont know how to do negation
        else
            OLD_IFS=$IFS
            IFS=':'
            for p in $PATHS; do
                # skip empty
                [ -z "$p" ] && continue

                # if exists
                if [ -e "$p" ]; then
                    eval "$1=\$p"
                    IFS=$OLD_IFS
                    return 0
                fi
            done

            # failed to get a path from the result
            IFS=$OLD_IFS
        fi

        # couldn't get from qt
        if [ -e "$DEFAULT_DIR_0" ]; then
            eval "$1=\$DEFAULT_DIR_0"
            return 0
        fi

        if [ -e "$DEFAULT_DIR_1" ]; then
            eval "$1=\$DEFAULT_DIR_1"
            return 0
        fi

        # failed to get a path at all

        return 1
    else
        eval "$1=\$SERVICE_MENU_DIR"
        return 0
    fi

}

# copy_with_sudo src dest
# elevates if needed
copy_with_sudo() {
    local src="$1"
    local dst="$2"

    # if writable
    if [ -w "$(dirname "$dst")" ]; then
        cp "$src" "$dst"
    else
        # -E preserves environment variables
        sudo -E cp "$src" "$dst"
    fi
}


SERVICE_MENU_STORAGE_DIR=
get_svcmenu_dir SERVICE_MENU_STORAGE_DIR

if [ -z "${SERVICE_MENU_STORAGE_DIR}" ]; then
    echo "Failed to locate service menu directory. Please specify one with the SERVICE_MENU_DIR environment variable when running this script instead."
    exit 1
fi

echo "Service menu directory: $SERVICE_MENU_STORAGE_DIR"

if [ -e "${SERVICE_MENU_STORAGE_DIR}/nest-dolphin.desktop" ]; then
    echo "nest-dolphin is already installed!"
    exit 1
fi

copy_with_sudo "/tmp/nest-dolphin.desktop" "${SERVICE_MENU_STORAGE_DIR}/nest-dolphin.desktop"
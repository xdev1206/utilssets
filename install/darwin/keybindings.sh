#!/bin/bash

DIR=~/Library/KeyBindings
FILE="$DIR/DefaultKeyBinding.dict"

# 1. Create directory if missing
mkdir -p "$DIR"

# 2. Backup existing file
if [ -f "$FILE" ]; then
    BACKUP="$FILE.bak.$(date +%s)"
    cp "$FILE" "$BACKUP"
    echo "[INFO] Backup created: $BACKUP"
fi

# 3. Write configuration
cat <<EOF > "$FILE"
{
    "\UF729" = "moveToBeginningOfLine:";          /* Home */
    "\UF72B" = "moveToEndOfLine:";                /* End */
    "\UF72C"  = "pageUp:";
    "\UF72D"  = "pageDown:";
    "$\UF729" = "moveToBeginningOfLineAndModifySelection:"; /* Shift+Home */
    "$\UF72B" = "moveToEndOfLineAndModifySelection:";       /* Shift+End */
}
EOF

echo "[SUCCESS] Configuration updated."
echo "[NOTE] Please restart your applications for changes to take effect."


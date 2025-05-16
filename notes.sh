#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CONFIG_FILE="$SCRIPT_DIR/config"


if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else 
    echo -e "Config file not found. Please create one with EDITOR, GITHUB_TOKEN, NOTES_DIR, and GITHUB_REPO."
fi

# $0 is a speacial variable that stores the filename
show_help() {
    echo "Usage: $0 [command] [note_name or keyword]"
    echo ""
    echo "Commands:"
    echo "  open <note_name>    Create or edit a note"
    echo "  daily               Create or edit today's journel entry"
    echo "  rename <old_name> <new_name> rename a note"
    echo "  delete <note_name>  Delete a note"
    echo "  list                List all notes"
    echo "  browse              Browse and open notes via TUI"
    echo "  recent              List 5 recently edited notes"
    echo "  search <keyword>    Search notes for a keyword"
    echo "  sync                Commit & push notes to GitHub"
}

list_notes() {
    # sed command is removing the $NOTES_DIR prefix from the results 
    # So we get only relative paths and file names in the result
    find "$NOTES_DIR" -type f -name "*.md" | sed "s|$NOTES_DIR/||"
}

# $1 is the first command line argument passed to the shell script
case "$1" in 
    open)
        # -z returns true if string is empty
        [[ -z "$2" ]] && echo "Note name required." && exit 1
        mkdir -p "$(dirname "$NOTES_DIR/$2")"
        $EDITOR "$NOTES_DIR/$2.md"
        ;;
    daily)
        JOURNEL_DIR="$NOTES_DIR/journal"
        mkdir -p "$JOURNEL_DIR"
        TODAY=$(date +%Y-%m-%d)
        $EDITOR "$JOURNEL_DIR/$TODAY.md"
        ;;
    delete)
        [[ -z "$2" ]] && echo "Note name required." && exit 1
        NOTE_PATH="$NOTES_DIR/$2.md"
        if [[ -f "$NOTE_PATH" ]]; then
            rm "$NOTE_PATH"
            echo "Deleted $2"
        else 
            echo "Note not found."
        fi
        ;;
    rename)
        [[ -z "$2" || -z "$3" ]] && echo "Both old name and new name are required." && exit 1
        NOTE_PATH="$NOTES_DIR/$2.md"
        if [[ -f "$NOTE_PATH" ]]; then
            mv "$NOTE_PATH" "$NOTES_DIR/$3.md"
            echo "Renamed $2 to $3"
        else 
            echo "Note not found."
        fi
        ;;
    list)
        list_notes
        ;;
    recent)
        echo "Recent notes:"
        find "$NOTES_DIR" -type f -name "*.md" -printf '%T@ %p\n' |
            sort -nr | head -n 5 | cut -d' ' -f2- | sed "s|$NOTES_DIR/||"
        ;;
    browse)
        CURRENT_DIR="$NOTES_DIR"
        GO_BACK=$(gum style --foreground 190 "Go Back") # Yellow
        EXIT=$(gum style --foreground 196 "Exit")       # Red

        while true; do
            FILE=$(gum choose --header="Select a file or folder to open" $(ls --group-directories-first "$CURRENT_DIR") "$GO_BACK" "$EXIT")

            [[ "$FILE" == "Exit" ]] && echo "Exiting" && exit 0

            if [[ "$FILE" == "Go Back" ]]; then
                if [[ "$CURRENT_DIR" == "$NOTES_DIR" ]]; then
                    echo "Already at the root directory. Cannot go back further."
                    continue
                else
                    CURRENT_DIR=$(dirname "$CURRENT_DIR")
                    continue
                fi
            fi

            if [[ -f "$CURRENT_DIR/$FILE" && "$FILE" == *.md ]]; then
                $EDITOR "$CURRENT_DIR/$FILE"
                break
            elif [[ -d "$CURRENT_DIR/$FILE" ]]; then
                CURRENT_DIR="$CURRENT_DIR/$FILE"
            else 
                echo "Please select a valid Markdown file or folder."
            fi
        done
        ;;
    search)
        [[ -z "$2" ]] && echo "Keyword required." && exit 1
        # -rn --> recursive and include line number
        grep -rn --color=always "$2" "$NOTES_DIR"
        ;;
    sync)
        if [[ -z "$GITHUB_TOKEN" || -z "$GITHUB_REPO" ]]; then
            echo "Github token or repo not set in the config"
            exit 1
        fi

        cd "$NOTES_DIR"

        git pull "https://$GITHUB_TOKEN@github.com/$GITHUB_REPO.git"
        git add .
        git commit -m "Sync notes: $(date)" || echo -e "No changes to commit"
        git push "https://$GITHUB_TOKEN@github.com/$GITHUB_REPO.git"
        ;;
    help)
        show_help
        ;;
    *)
        echo "Invalid command. Use '$0 help' to see avalible commands"
esac

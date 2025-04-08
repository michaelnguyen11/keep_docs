#!/bin/bash

# Script to convert PlantUML diagrams to PNG images
# Usage: 
#   ./scripts/puml_to_image.sh [input]
#
# Parameters:
#   input - File or directory to process (default: diagrams directory)
#
# Examples:
#   ./scripts/puml_to_image.sh                             # Convert all .puml files in diagrams directory
#   ./scripts/puml_to_image.sh diagrams/c4/c4_context.puml # Convert a specific file
#   ./scripts/puml_to_image.sh diagrams/c4                 # Convert all .puml files in a specific directory

# Determine script directory and root directory (parent of script directory)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

# Set default input path if not provided
if [ $# -eq 0 ]; then
    INPUT_PATH="$ROOT_DIR/diagrams"
else
    # Convert relative path to absolute using the current directory
    if [[ "$1" = /* ]]; then
        INPUT_PATH="$1"
    else
        INPUT_PATH="$(cd "$(dirname "$1")" &> /dev/null && pwd)/$(basename "$1")"
    fi
fi

# Check if PlantUML jar exists
PLANTUML_JAR="$SCRIPT_DIR/plantuml-1.2025.2.jar"
if [ ! -f "$PLANTUML_JAR" ]; then
    echo "PlantUML jar file not found in $SCRIPT_DIR"
    echo "Please download it from https://plantuml.com/download and place it in the scripts directory"
    exit 1
fi

# Create images directory if it doesn't exist
IMAGES_DIR="$ROOT_DIR/images"
mkdir -p "$IMAGES_DIR"

# Function to convert a single PlantUML file to PNG
convert_file() {
    local input_file="$1"
    local output_file="$IMAGES_DIR/$(basename "${input_file%.puml}").png"
    echo "Processing: $input_file -> $output_file"
    java -jar "$PLANTUML_JAR" -tpng -o "$(dirname "$output_file")" "$input_file"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to convert $input_file to PNG"
    fi
}

# Function to process a directory of PlantUML files
process_directory() {
    local dir="$1"
    echo "Processing directory: $dir"
    find "$dir" -name "*.puml" -type f | while read -r file; do
        convert_file "$file"
    done
}

echo "Converting PlantUML diagrams to PNG format..."
echo "Root directory: $ROOT_DIR"
echo "Input path: $INPUT_PATH"

# Check if input path exists
if [ ! -e "$INPUT_PATH" ]; then
    echo "Error: Input '$INPUT_PATH' is not a valid file or directory."
    exit 1
fi

# Process input as file or directory
if [ -f "$INPUT_PATH" ]; then
    convert_file "$INPUT_PATH"
elif [ -d "$INPUT_PATH" ]; then
    process_directory "$INPUT_PATH"
else
    echo "Error: Input '$INPUT_PATH' is neither a file nor a directory."
    exit 1
fi

# Check if any PNG files were created
PNG_COUNT=$(find "$IMAGES_DIR" -name "*.png" -type f | wc -l)
if [ $PNG_COUNT -eq 0 ]; then
    echo "No PNG files were created. Check for errors above."
    exit 1
fi

echo "Conversion complete. PNG files are available in the 'images' directory."
echo "Generated files:"
ls -la "$IMAGES_DIR"/*.png

# Create HTML index of PNG diagrams
echo "Creating HTML index of PNG diagrams..."
INDEX_FILE="$IMAGES_DIR/index.html"

cat > "$INDEX_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Keep AIOps Platform - Diagrams</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        h2 { color: #555; margin-top: 30px; }
        .diagram { margin-bottom: 30px; }
        .diagram img { max-width: 100%; border: 1px solid #ddd; }
        .diagram p { font-style: italic; color: #666; }
    </style>
</head>
<body>
    <h1>Keep AIOps Platform - Architecture Diagrams</h1>
    
    <h2>C4 Architecture Diagrams</h2>
    <div class="diagrams-section">
EOF

# Add C4 diagrams
find "$IMAGES_DIR" -name "C4_*.png" -o -name "c4_*.png" -type f | sort | while read -r img; do
    filename=$(basename "$img" .png)
    title=$(echo "$filename" | sed 's/[Cc]4_//' | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')
    echo "        <div class=\"diagram\">" >> "$INDEX_FILE"
    echo "            <h3>$title</h3>" >> "$INDEX_FILE"
    echo "            <img src=\"$(basename "$img")\" alt=\"$title\">" >> "$INDEX_FILE"
    echo "        </div>" >> "$INDEX_FILE"
done

cat >> "$INDEX_FILE" << EOF
    </div>
    
    <h2>Class Diagrams</h2>
    <div class="diagrams-section">
EOF

# Add class diagrams
find "$IMAGES_DIR" -name "*[cC]lass_[dD]iagram*.png" -o -name "*_Class_Diagram.png" -o -name "Core_Domain_Model.png" -type f | sort | while read -r img; do
    filename=$(basename "$img" .png)
    title=$(echo "$filename" | sed 's/_/ /g' | sed 's/class diagram/Class Diagram/i' | sed 's/\b\(.\)/\u\1/g')
    echo "        <div class=\"diagram\">" >> "$INDEX_FILE"
    echo "            <h3>$title</h3>" >> "$INDEX_FILE"
    echo "            <img src=\"$(basename "$img")\" alt=\"$title\">" >> "$INDEX_FILE"
    echo "        </div>" >> "$INDEX_FILE"
done

cat >> "$INDEX_FILE" << EOF
    </div>
    
    <h2>Sequence Diagrams</h2>
    <div class="diagrams-section">
EOF

# Add sequence diagrams
find "$IMAGES_DIR" -name "*[sS]equence*.png" -o -name "Workflow_Execution.png" -o -name "Alert_Processing.png" -o -name "AI_Enrichment.png" -type f | sort | while read -r img; do
    filename=$(basename "$img" .png)
    title=$(echo "$filename" | sed 's/_/ /g' | sed 's/sequence diagram/Sequence Diagram/i' | sed 's/\b\(.\)/\u\1/g')
    echo "        <div class=\"diagram\">" >> "$INDEX_FILE"
    echo "            <h3>$title</h3>" >> "$INDEX_FILE"
    echo "            <img src=\"$(basename "$img")\" alt=\"$title\">" >> "$INDEX_FILE"
    echo "        </div>" >> "$INDEX_FILE"
done

cat >> "$INDEX_FILE" << EOF
    </div>
</body>
</html>
EOF

echo "HTML index created at $INDEX_FILE"

exit 0 
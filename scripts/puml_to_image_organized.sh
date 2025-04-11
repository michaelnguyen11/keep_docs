#!/bin/bash

# Script to convert PlantUML diagrams to PNG images in an organized structure
# Usage: 
#   ./scripts/puml_to_image_organized.sh [input]
#
# Parameters:
#   input - File or directory to process (default: all diagrams)
#
# Examples:
#   ./scripts/puml_to_image_organized.sh                                         # Convert all diagrams
#   ./scripts/puml_to_image_organized.sh keep_aiops/diagrams/c4/c4_context.puml  # Convert a specific file
#   ./scripts/puml_to_image_organized.sh keep_aiops/diagrams/c4                  # Convert all .puml files in a specific directory

# Determine script directory and root directory (parent of script directory)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

# Check if PlantUML jar exists
PLANTUML_JAR="$SCRIPT_DIR/plantuml-1.2025.2.jar"
if [ ! -f "$PLANTUML_JAR" ]; then
    echo "PlantUML jar file not found in $SCRIPT_DIR"
    echo "Please download it from https://plantuml.com/download and place it in the scripts directory"
    exit 1
fi

# Set default input paths if not provided
if [ $# -eq 0 ]; then
    echo "Processing all diagrams in keep_aiops and keep_agentic directories..."
    # Process all diagrams in both directories
    "$0" "$ROOT_DIR/keep_aiops/diagrams"
    "$0" "$ROOT_DIR/keep_agentic/diagrams"
    exit 0
else
    # Convert relative path to absolute using the current directory
    if [[ "$1" = /* ]]; then
        INPUT_PATH="$1"
    else
        INPUT_PATH="$(cd "$(dirname "$1")" &> /dev/null && pwd)/$(basename "$1")"
    fi
fi

echo "Converting PlantUML diagrams to PNG format..."
echo "Root directory: $ROOT_DIR"
echo "Input path: $INPUT_PATH"

# Check if input path exists
if [ ! -e "$INPUT_PATH" ]; then
    echo "Error: Input '$INPUT_PATH' is not a valid file or directory."
    exit 1
fi

# Determine the output directory based on the input path
if [[ "$INPUT_PATH" == *"/keep_aiops/"* ]]; then
    IMAGES_DIR="$ROOT_DIR/keep_aiops/images"
    TYPE="Keep AIOps"
elif [[ "$INPUT_PATH" == *"/keep_agentic/"* ]]; then
    IMAGES_DIR="$ROOT_DIR/keep_agentic/images"
    TYPE="Agentic AI Integration"
else
    echo "Error: Input path must be within keep_aiops or keep_agentic directories."
    exit 1
fi

# Create images directory if it doesn't exist
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

echo "Conversion complete. PNG files are available in the '$IMAGES_DIR' directory."
echo "Generated files:"
ls -la "$IMAGES_DIR"/*.png 2>/dev/null || echo "No PNG files found."

# Create HTML index of PNG diagrams
echo "Creating HTML index of PNG diagrams..."
INDEX_FILE="$IMAGES_DIR/index.html"

cat > "$INDEX_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$TYPE - Diagrams</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        h2 { color: #555; margin-top: 30px; }
        .diagram { margin-bottom: 30px; }
        .diagram img { max-width: 100%; border: 1px solid #ddd; }
        .diagram p { font-style: italic; color: #666; }
        .back-link { margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="back-link">
        <a href="../README.md">Back to Documentation</a>
    </div>
    <h1>$TYPE - Architecture Diagrams</h1>
    
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

    <h2>Other Diagrams</h2>
    <div class="diagrams-section">
EOF

# Add any remaining diagrams that don't fit in the above categories
find "$IMAGES_DIR" -name "*.png" | grep -v -e "C4_" -e "c4_" -e "[cC]lass_[dD]iagram" -e "_Class_Diagram" -e "Core_Domain_Model" -e "[sS]equence" -e "Workflow_Execution" -e "Alert_Processing" -e "AI_Enrichment" | sort | while read -r img; do
    filename=$(basename "$img" .png)
    title=$(echo "$filename" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')
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

# If no other inputs were specified, create a combined index
if [ $# -eq 0 ]; then
    echo "Creating combined index..."
    COMBINED_INDEX="$ROOT_DIR/images/index.html"
    
    cat > "$COMBINED_INDEX" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Keep Documentation - Diagrams</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        h2 { color: #555; margin-top: 30px; }
        .section { margin-bottom: 40px; }
        .btn { 
            display: inline-block; 
            margin: 10px;
            padding: 15px 25px;
            background-color: #4CAF50;
            color: white;
            text-decoration: none;
            font-size: 18px;
            border-radius: 5px;
            text-align: center;
        }
        .btn:hover {
            background-color: #45a049;
        }
    </style>
</head>
<body>
    <h1>Keep Documentation - Diagrams</h1>
    
    <div class="section">
        <h2>Choose a Diagram Set:</h2>
        <a href="keep_aiops/images/index.html" class="btn">Keep AIOps Platform Diagrams</a>
        <a href="keep_agentic/images/index.html" class="btn">Agentic AI Integration Diagrams</a>
    </div>
</body>
</html>
EOF
    
    echo "Combined index created at $COMBINED_INDEX"
fi

exit 0 
CURRENT_FOLDER=`cd $(dirname "$0"); pwd`
SRC_FOLDER="$(dirname "$CURRENT_FOLDER")" 
DIST_FOLDER="$SRC_FOLDER/dist"
GSEA_FOLDER="$DIST_FOLDER/lib/GSEA"
GSEA_DIST_FOLDER="$GSEA_FOLDER/dist"

echo $SRC_FOLDER

# Copy everything to dist folder
echo "Moving files to dist folder..."
rm -rf "$DIST_FOLDER"
mkdir "$DIST_FOLDER"
mkdir "$DIST_FOLDER/log"
cp -r "$SRC_FOLDER/lib" "$DIST_FOLDER/lib"
cp -r "$SRC_FOLDER/public" "$DIST_FOLDER/public"
cp -r "$SRC_FOLDER/script" "$DIST_FOLDER/script"
rm "$DIST_FOLDER/script/build.sh"
cp -r "$SRC_FOLDER/templates" "$DIST_FOLDER/templates"

# Build GSEA and replace source file by jar files
echo "Building GSEA Runner..."
mkdir "$GSEA_FOLDER/classes"
mkdir "$GSEA_FOLDER/dist"
javac $GSEA_FOLDER/src/**/*.java -cp "$GSEA_FOLDER/lib/*" -d $GSEA_FOLDER/classes
cd "$GSEA_FOLDER/classes"
jar cfm "$GSEA_DIST_FOLDER/GSEARunner.jar" "$GSEA_FOLDER/Manifest.txt" **/*.class
mv "$GSEA_FOLDER/config.properties" "$GSEA_DIST_FOLDER/config.properties"
mv "$GSEA_FOLDER/lib" "$GSEA_DIST_FOLDER/lib"

mv  "$GSEA_FOLDER/dist" "$DIST_FOLDER/GSEAtemp"
rm -r "$GSEA_FOLDER"
mv "$DIST_FOLDER/GSEAtemp" "$GSEA_FOLDER"
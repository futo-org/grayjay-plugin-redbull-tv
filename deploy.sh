#!/bin/sh
DOCUMENT_ROOT=/var/www/sources

# Use environment variable to determine deployment type
PRE_RELEASE=${PRE_RELEASE:-false}  # Default to false if not set

# Determine deployment directory
if [ "$PRE_RELEASE" = "true" ]; then
    RELATIVE_PATH="pre-release/RedbullTv"
else
    RELATIVE_PATH="RedbullTv"
fi

DEPLOY_DIR="$DOCUMENT_ROOT/$RELATIVE_PATH"
PLUGIN_URL_ROOT="https://plugins.grayjay.app/$RELATIVE_PATH"
SOURCE_URL="$PLUGIN_URL_ROOT/RedBullTvConfig.json"

# Take site offline
echo "Taking site offline..."
touch $DOCUMENT_ROOT/maintenance.file

# Swap over the content
echo "Deploying content..."
mkdir -p "$DEPLOY_DIR"
cp RedBullTvIcon.png "$DEPLOY_DIR"
cp RedBullTvConfig.json "$DEPLOY_DIR"
cp RedBullTvScript.js "$DEPLOY_DIR"

# Update the sourceUrl in RedBullTvConfig.json
echo "Updating sourceUrl in RedBullTvConfig.json..."
jq --arg sourceUrl "$SOURCE_URL" '.sourceUrl = $sourceUrl' "$DEPLOY_DIR/RedBullTvConfig.json" > "$DEPLOY_DIR/RedBullTvConfig_temp.json"
if [ $? -eq 0 ]; then
    mv "$DEPLOY_DIR/RedBullTvConfig_temp.json" "$DEPLOY_DIR/RedBullTvConfig.json"
else
    echo "Failed to update RedBullTvConfig.json" >&2
    exit 1
fi

sh sign.sh "$DEPLOY_DIR/RedBullTvScript.js" "$DEPLOY_DIR/RedBullTvConfig.json"

# Notify Cloudflare to wipe the CDN cache
echo "Purging Cloudflare cache for zone $CLOUDFLARE_ZONE_ID..."
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/purge_cache" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H "Content-Type: application/json" \
     --data '{"files":["'"$PLUGIN_URL_ROOT/RedBullTvIcon.png"'", "'"$PLUGIN_URL_ROOT/RedBullTvConfig.json"'", "'"$PLUGIN_URL_ROOT/RedBullTvScript.js"'"]}'

# Take site back online
echo "Bringing site back online..."
rm "$DOCUMENT_ROOT/maintenance.file"

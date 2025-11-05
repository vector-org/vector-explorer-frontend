#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "Usage: yarn dev:preset <preset_name>"
  exit 1
fi

preset_name="$1"
config_file="./configs/envs/.env.${preset_name}"
secrets_file="./configs/envs/.env.secrets"

if [ ! -f "$config_file" ]; then
    echo "Error: File '$config_file' not found."
    exit 1
fi

# remove previous assets
rm -rf ./public/assets/configs
rm -rf ./public/assets/multichain
rm -rf ./public/assets/essential-dapps
rm -rf ./public/assets/envs.js

# download assets for the running instance
dotenv \
  -e $config_file \
  -- bash -c './deploy/scripts/download_assets.sh ./public/assets/configs'

# generate multichain config (adjust condition accordingly)
if [[ "$preset_name" == "optimism_superchain" ]]; then
  dotenv \
    -e $config_file \
    -- bash -c 'cd deploy/tools/multichain-config-generator && yarn install --silent && yarn build && yarn generate'
fi

# generate essential dapps chains config if marketplace essential dapps enabled
dotenv \
  -e $config_file \
  -- bash -c 'cd deploy/tools/essential-dapps-chains-config-generator && yarn install --silent && yarn build && yarn generate'

source ./deploy/scripts/build_sprite.sh
echo ""

git_commit_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
# fall back to commit hash when no git tags are present
git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "${git_commit_sha}")

# generate envs.js file and run the app
dotenv \
  -v NEXT_PUBLIC_GIT_COMMIT_SHA="${git_commit_sha}" \
  -v NEXT_PUBLIC_GIT_TAG="${git_tag}" \
  -v NEXT_PUBLIC_ICON_SPRITE_HASH="${NEXT_PUBLIC_ICON_SPRITE_HASH}" \
  -e $config_file \
  -e $secrets_file \
  -- bash -c './deploy/scripts/make_envs_script.sh && next dev -p $NEXT_PUBLIC_APP_PORT' |
pino-pretty

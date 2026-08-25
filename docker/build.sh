#! /usr/bin/env bash

#
# Manually run a docker build using the currently
# checked out git branch as the SGN branch
# 
# ./build.sh [image] [tag]
# 

DOCKER_IMAGE=${1:-triticeaetoolbox/breedbase_web}
DOCKER_TAG=${2:-latest}

get_script_dir() {
    local SOURCE=$0
    while [ -h "$SOURCE" ]; do # Resolve $SOURCE until the file is no longer a symlink
        DIR=$(cd -P "$(dirname "$SOURCE")" && pwd)
        SOURCE=$(readlink "$SOURCE")
        [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # If $SOURCE was a relative symlink, resolve it relative to the symlink base directory
    done
    DIR=$(cd -P "$(dirname "$SOURCE")" && pwd)
    echo "$DIR"
}

SCRIPT_DIR=$(get_script_dir)
REPO_DIR=$(readlink -f "$SCRIPT_DIR/../")

# Get the first remote
remote=$(git -C "$REPO_DIR" remote | head -1)
url=$(git -C "$REPO_DIR" remote get-url $remote)

# Parse the remote URL into user/repo
SGN_REPO="triticeaetoolbox/sgn"
re="^(https|git)(:\/\/|@)([^\/:]+)[\/:]([^\/:]+)\/(.+)(.git)*$"
if [[ $url =~ $re ]]; then
    user=${BASH_REMATCH[4]}
    repo=${BASH_REMATCH[5]}
    repo=$(basename "$repo" .git)
    SGN_REPO="$user/$repo"
fi

# Get the current branch and commit
SGN_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)
SGN_COMMIT=$(git -C "$REPO_DIR" rev-parse HEAD)

# Run docker build
echo "--> Building Docker Image [$DOCKER_IMAGE:$DOCKER_TAG]"
echo "    SGN_REPO: $SGN_REPO"
echo "    SGN_BRANCH: $SGN_BRANCH [$SGN_COMMIT]"
docker build -t $DOCKER_IMAGE:$DOCKER_TAG \
    --build-arg SGN_COMMIT=$SGN_COMMIT \
    --build-arg SGN_REPO=$SGN_REPO \
    --build-arg SGN_BRANCH=$SGN_BRANCH \
    $REPO_DIR/docker
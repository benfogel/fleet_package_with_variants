#!/bin/bash
set +x

export TAG=$1

git tag $TAG
git push origin --tags

function main() {
    number_of_rollouts=$(get_number_of_rollouts)

    for i in $(seq 1 $number_of_rollouts); do
        echo "On rollout $i"

        number_of_subrollouts=$(get_number_of_subrollouts $i)

        for j in $(seq 1 $number_of_subrollouts); do
            TARGET=$(get_target_from_subrollout $i $j)
            PACKAGE_NAME=$(get_package_name)
            export PACKAGE_NAME_AND_TARGET="$PACKAGE_NAME-$TARGET"

            export REPO_NAME=$(get_default_property "repo_name")
            export SERVICE_ACCOUNT=$(get_default_property "service_account")
            export REGION=$(get_default_property "region")
            export REPO_NAME=$(get_default_property "repo_name")
            export ROLLOUT_STRATEGY=$(get_default_property "rolloutStrategy")
            export TARGET_INFO=$(get_target_info $TARGET)
            export TARGET_PROJECT=$(get_target_project $TARGET)
            export PROJECT=${TARGET_PROJECT#*/} # strips `projects/` prefix
            export VARIANT_SELECTOR=$(get_default_property "variantSelector")

            envsubst < "fleet-package.yaml.template" |
                yq ". | .target += $TARGET_INFO
                      | .rolloutStrategy += $ROLLOUT_STRATEGY
                      | .variantSelector += $VARIANT_SELECTOR" > "/tmp/$PACKAGE_NAME_AND_TARGET.yaml"

            echo "On subrollout $i $PACKAGE_NAME_AND_TARGET"

            echo $PACKAGE_NAME_AND_TARGET

            #start_rollout $PACKAGE_NAME_AND_TARGET &
        done

        wait
    done
}

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

PIPELINE_FILE="$SCRIPT_DIR/pipeline.yaml"

function get_number_of_rollouts() {
    cat $PIPELINE_FILE | yq '.rollout_sequence | length'
} 

function get_number_of_subrollouts() {
    cat $PIPELINE_FILE | yq ".rollout_sequence[$(($1-1))].targets | length"
}

function get_target_from_subrollout() {
    cat $PIPELINE_FILE | yq ".rollout_sequence[$(($1-1))].targets[$(($2-1))]" -r
}

function get_target_info() {
    cat $PIPELINE_FILE | yq ".targets[\"$1\"]" -o json -I0 -r
}

function get_default_property() {
    cat $PIPELINE_FILE | yq ".defaults[\"$1\"]" -o json -I0 -r
}

function get_package_name() {
    cat $PIPELINE_FILE | yq ".package_name" -r
}

function get_target_project() {
    cat $PIPELINE_FILE | yq ".targets[\"$1\"] | .fleet.project" -o json -I0 -r
}

function start_rollout() {
    ROLLOUT_CONFIG=/tmp/$1.yaml

    PROJECT_RESOURCE=$(cat "$ROLLOUT_CONFIG" | yq '.target.fleet.project' -r) # returns format of projects/PROJECT_NAME
    PROJECT=${PROJECT_RESOURCE#*/} # strips `projects/` prefix

    PACKAGE_NAME_RESOURCE=$(cat "$ROLLOUT_CONFIG" | yq '.name' -r) # returns format of projects/PROJECT_NAME/locations/REGION/fleetPackages/PACKAGE_NAME
    PACKAGE_NAME=${PACKAGE_NAME_RESOURCE##*/} # strips `projects/PROJECT_NAME/locations/REGION/fleetPackages/` prefix

    gcloud alpha container fleet packages describe $PACKAGE_NAME \
        --location us-central1 \
        --project=$PROJECT

    if [ $? -eq 0 ]; then
        # Trigger new rollout
        "gcloud alpha container fleet packages update $PACKAGE_NAME \
            --source="$ROLLOUT_CONFIG" \
            --project=$PROJECT"
    else
        # First deployment of package
        gcloud alpha container fleet packages create $PACKAGE_NAME \
            --source="$ROLLOUT_CONFIG" \
            --project=$PROJECT
    fi

    # Poll for rollout to complete
    STATE="PENDING"
    RELEASE_NAME=$(echo $TAG | tr . -) # releases are named the same as the tag, but with `-` instead of `.`

    while [[ "$STATE" != "COMPLETED" ]]; do
        echo "Waiting for rollout $RELEASE_NAME to complete..."

        STATE=$(gcloud alpha container fleet packages rollouts list --fleet-package \
            $PACKAGE_NAME --filter="release:$RELEASE_NAME" \
            --project=$PROJECT \
            --format yaml | yq '.info.state' -r)

        sleep 5
    done
}

main "$@"
#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
#export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup_file() { 
  export OUTPUT_PATH="$PWD/tests/.outputs/"  
  mkdir -p "${OUTPUT_PATH}"
  rm -f ${OUTPUT_PATH}/*

  export DATA_PATH="$PWD/tests/.data/"
  mkdir -p "${DATA_PATH}"
  rm -f ${DATA_PATH}/*
}

setup() {
  export BUILDKITE_STEP_ID="080b7d73-986d-4a39-a510-b34f9faf4710"
  export BUILDKITE_LABEL="testing"
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_MODULE_DIR="test/test"
  export BUILDKITE_PLUGINS="$( jq -c '.' $PWD/tests/data/buildkite_plugins.json)"
  export STEP_OUTPUT="$(jq -c '.' $PWD/tests/data/step.json )"
}


@test "Generates a pipeline with a deploy module" { 
  MODULE="app"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT="${OUTPUT_PATH}/${BATS_TEST_NAME// /"_"}.yml"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH="${DATA_PATH}/${BATS_TEST_NAME// /"_"}_output_module_groups.json"
  echo "{\"Group1\": [\"$PWD/test/test/$MODULE\"]}" > "${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH}"

  stub buildkite-agent \
    "step get --format json : echo '${STEP_OUTPUT}'" \
    'annotate \* \* \* \* \* \* : echo Noted' \
    'pipeline upload : echo Uploading pipeline'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Uploading pipeline"
  assert_output --partial "Modules for deployment - $MODULE"

  unstub buildkite-agent

  # Is pipeline valid yaml
  run yq '.' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT
  assert_success

  run yq '.steps[0].command' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT
  assert_output "buildkite-agent meta-data set modules \"${MODULE}\""

  run yq '.steps[0].label' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT 
  assert_output ":terragrunt: [${BUILDKITE_LABEL}] Setting Module to Deploy"

  run yq '.steps[2].label' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT 
  assert_output ":terragrunt: [${BUILDKITE_LABEL}] Plan Modules"

  run yq '.steps[3].block' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT 
  assert_output ":terragrunt: [${BUILDKITE_LABEL}] Apply Changes?"

  run yq '.steps[4].label' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT 
  assert_output ":terragrunt: [${BUILDKITE_LABEL}] Apply Modules"

  run yq '.steps[2].key' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT 
  assert_output "plan:test:test"
}

@test "Generates a pipeline with a deploy module and refresh" { 
  MODULE="app"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT="${OUTPUT_PATH}/${BATS_TEST_NAME// /"_"}.yml"
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_0="passwords"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH="${DATA_PATH}/${BATS_TEST_NAME// /"_"}_output_module_groups.json"
  echo "{\"Group1\": [\"$PWD/test/test/$MODULE\", \"$PWD/test/test/${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_0}\"]}" > "${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH}"

  stub buildkite-agent \
    "step get --format json : echo '${STEP_OUTPUT}'" \
    'annotate \* \* \* \* \* \* : echo Noted' \
    'pipeline upload : echo "Uploading pipeline"'

  run "$PWD/hooks/post-command"
  
  assert_success
  assert_line "Data modules - $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_0 "
  assert_line "Modules for deployment - $MODULE "
  assert_line "Uploading pipeline"

  unstub buildkite-agent

  # The refresh module should never be planned
  run yq '.' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT
  assert_success
  refute_output --partial "terragrunt plan --terragrunt-working-dir ${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_MODULE_DIR}/${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_0}"

  # The first command of the plan step should be a refresh
  run yq '.steps[2].command' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT
  assert_success
  assert_output --partial "terragrunt refresh --terragrunt-working-dir \"${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_MODULE_DIR}/${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_0}\""  
}

@test "Generates a pipeline with a deploy module and a filter" { 
  MODULE="app"
  DANGER_MODULE="danger_module"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT="${OUTPUT_PATH}/${BATS_TEST_NAME// /"_"}.yml"
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_ALLOWED_MODULES_0="${MODULE}"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH="${DATA_PATH}/${BATS_TEST_NAME// /"_"}_output_module_groups.json"
  echo "{\"Group1\":[\"$PWD/test/test/$MODULE\",\"$PWD/test/test/$DANGER_MODULE\"]}" > "${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH}"

  stub buildkite-agent \
    "step get --format json : echo '${STEP_OUTPUT}'" \
    'annotate \* \* \* \* \* \* : echo Noted' \
    'pipeline upload : echo Uploading pipeline'

  run "$PWD/hooks/post-command"

  assert_success
  assert_line "Uploading pipeline"
  assert_line "Discovered modules - $MODULE $DANGER_MODULE "
  assert_line "Modules after filtering - $MODULE "

  unstub buildkite-agent

  # Is pipeline valid yaml
  run yq '.' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT
  assert_success

  run yq '.steps[0].command' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT
  assert_output "buildkite-agent meta-data set modules \"${MODULE}\""
}

@test "Generates a pipeline with a deploy module and plan encryption" { 
  MODULE="app"
  DANGER_MODULE="danger_module"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT="${OUTPUT_PATH}/${BATS_TEST_NAME// /"_"}.yml"
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_ALLOWED_MODULES_0="${MODULE}"
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_PLAN_ENCRYPTION_KMS_KEY_ARN="arn:aws:kms:ap-southeast-2:123456789012:key/5a14434f-9d4e-55dh-27df-f32711fe0492"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH="${DATA_PATH}/${BATS_TEST_NAME// /"_"}_output_module_groups.json"
  echo "{\"Group1\":[\"$PWD/test/test/$MODULE\",\"$PWD/test/test/$DANGER_MODULE\"]}" > "${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH}"

  stub buildkite-agent \
    "step get --format json : echo '${STEP_OUTPUT}'" \
    'annotate \* \* \* \* \* \* : echo Noted' \
    'pipeline upload : echo Uploading pipeline'

  run "$PWD/hooks/post-command"

  assert_success
  
  unstub buildkite-agent

  # Is pipeline valid yaml
  run yq '.' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT
  assert_success

  run yq '.steps[0].command' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT
  assert_output "buildkite-agent meta-data set modules \"${MODULE}\""
}

@test "Generates a pipeline with multiple refrehses and deploy modules" {
  MODULE_1="app"
  MODULE_2="db"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT="${OUTPUT_PATH}/${BATS_TEST_NAME// /"_"}.yml"
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_0="passwords"
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_1="constants"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH="${DATA_PATH}/${BATS_TEST_NAME// /"_"}_output_module_groups.json"
  echo "{\"Group1\": [\"$PWD/test/test/$MODULE_1\", \"$PWD/test/test/$MODULE_2\", \"$PWD/test/test/${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_0}\", \"$PWD/test/test/${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_1}\"]}" > "${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH}"

  stub buildkite-agent \
    "step get --format json : echo '${STEP_OUTPUT}'" \
    'annotate \* \* \* \* \* \* : echo Noted' \
    'pipeline upload : echo Uploading pipeline'

  run "$PWD/hooks/post-command"
  
  assert_success
  assert_output --partial "Data modules - $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_0 $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_1 "
  assert_line "Modules for deployment - $MODULE_1 $MODULE_2 "
  assert_line "Uploading pipeline"

  unstub buildkite-agent

  # The refresh module should never be planned
  run yq '.' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT
  assert_success
  refute_output --partial "terragrunt plan --terragrunt-working-dir ${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_MODULE_DIR}/${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_0}"
  refute_output --partial "terragrunt plan --terragrunt-working-dir ${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_MODULE_DIR}/${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_1}"

  # The first command of the plan step should be a refresh
  run yq '.steps[1].command' $BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT
  assert_success
  assert_line --partial "terragrunt refresh --terragrunt-working-dir \"${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_MODULE_DIR}/${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_0}\""
  assert_line --partial "terragrunt refresh --terragrunt-working-dir \"${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_MODULE_DIR}/${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DATA_MODULES_1}\""  
}

@test "Exits when no modules can be found to use" { 
  MODULE_1="app"
  MODULE_2="db"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT="${OUTPUT_PATH}/${BATS_TEST_NAME// /"_"}.yml"
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_ALLOWED_MODULES_0="other"
  
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH="${DATA_PATH}/${BATS_TEST_NAME// /"_"}_output_module_groups.json"
  echo "{\"Group1\": [\"$PWD/test/test/$MODULE_1\", \"$PWD/test/test/$MODULE_2\"]}" > "${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH}"

  stub buildkite-agent \
    "step get --format json : echo '${STEP_OUTPUT}'" \
    'annotate \* \* \* \* \* \* : echo Noted'

  run "$PWD/hooks/post-command"
  
  assert_failure
  assert_line "❌ No modules found for deployment"
  refute_line "Modules for deployment - $MODULE_1 $MODULE_2 "
  refute_line "Uploading pipeline"

  unstub buildkite-agent
}

@test "Exits happy when no modules can be found to use and no modules set to false" { 
  MODULE_1="app"
  MODULE_2="db"

  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_DEBUG_PIPELINE_OUTPUT="${OUTPUT_PATH}/${BATS_TEST_NAME// /"_"}.yml"
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_ALLOWED_MODULES_0="other"
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_FAIL_ON_NO_MODULES="false"
  
  export BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH="${DATA_PATH}/${BATS_TEST_NAME// /"_"}_output_module_groups.json"
  echo "{\"Group1\": [\"$PWD/test/test/$MODULE_1\", \"$PWD/test/test/$MODULE_2\"]}" > "${BUILDKITE_PLUGIN_TERRAGRUNT_WORKSPACE_OUTPUT_MODULE_GROUPS_PATH}"

  stub buildkite-agent \
    "step get --format json : echo '${STEP_OUTPUT}'" \
    'annotate \* \* \* \* \* \* : echo Noted'

  run "$PWD/hooks/post-command"
  
  assert_success
  assert_line "❌ No modules found for deployment"
  refute_line "Modules for deployment - $MODULE_1 $MODULE_2 "
  refute_line "Uploading pipeline"

  unstub buildkite-agent
}
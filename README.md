# Terragrunt Workspace Buildkite Plugin

Provides a standard pipeline for deploying terragrunt workspaces

The plugin generates a dynamic pipeline based on the modules discovered by terragrunt. 

The pipeline consists of:

- if more than 1 module is found to apply, A block step which allows you to select the modules to apply. This is ordered based on how it will be applied
- A command step which will run a plan for each of the selected modules and provide the output
- A block to confirm you want to run apply
- A command step to run apply for each of the selected modules

By default all modules found by terragrunt will be included in the block step, however you can filter this by providing a list of allowed modules. 

If you have modules that are just made up of data components that provide information to your other modules you can add them under the data_modules option, before running the plan or apply commands each of the data modules will be refreshed. This builds a local state file since modules without resources don't save their state in terraform.


## Example

Add the following to your `pipeline.yml`:

```yml
steps:
  - command: ~
    plugins:
      - fatzebra/terragrunt-workspace#v1.4.4:
          module_dir: "test/test/"
```

If you have the following terragrunt setup

```
- test
  - test
    - db
      - terragrunt.hcl
    - web
      - terragrunt.hcl
```

Then the block will ask you to deploy the db and web modules

### Module Discovery 

Modules are discovered using the terragrunt command `terragrunt output-module-groups` during a post-command hook, so if you don't have terragrunt installed on your agent and instead use the docker or docker-compose plugins this will fail to run. We recommend the [devopsinfra/docker-terragrunt](https://hub.docker.com/r/devopsinfra/docker-terragrunt) docker image with the docker plugin, the docker image has all the tools requried and the docker plugin saves having to have a docker-compose file.

After adding the docker plugin you also need to run the module discovery as a command, this is then used by the plugin to run the deployment.


```yml
steps:
  - command: buildkite-agent meta-data set terragrunt-workspace-module-groups "$(terragrunt output-module-groups --terragrunt-working-dir /test/test)"
    plugins:
      - fatzebra/terragrunt-workspace#v1.4.4:
        module_dir: "test/test/"
      - docker#v5.11.0:
        image: "devopsinfra/docker-terragrunt:aws-tf-1.9.7-tg-0.67.16"
        mount-buildkite-agent: true
```

The plugin also copies the env, plugin and agent configuration to any steps it generates so this will be applied for subsequent steps.

## Configuration

### `module_dir` (Required, string)

The relative path to the directory where the terragrunt modules you want to run are in.

### `allowed_modules` (Optional, array)

A list of directory/module names that can be used as part of this plugin

### `data_modules` (Optional, array)

The directory names of the modules you want to run `terragrunt refresh` each time a plan or apply is run on the `modules` or `always_modules`. Sometimes you might have modules that only have data components that lookup passwords, parameters etc. Since these don't save there state to a backend you need to refresh them each time to get their outputs.

### `terragrunt_args` (Optional, array)

A list of extra arguments to pass to any terragrunt commands

### `plan_encryption_kms_key_arn` (Optional, string)

An AWS kms key ARN to use to encrypt the tfplan state when passing between jobs. tfplan can contain sensitive data that you might not want people who can read your pipeline and access artifacts to see.

The encryption process uses [sops](https://github.com/getsops/sops) to encrypt the file contents as the plan generally be over the 4kb limit of a single kms encrypt operation. 

Due to a bug in sops you will need to have version v3.9.0 and above to perform the encryption operation without having a config file present.

### `debug_pipeline_output` (Optional, string)

Writes the pipeline to the nominated output path

### `fail_on_no_modules` (Optional, boolean)

If no modules are found for deployment should the pipeline fail


## Developing

To run the tests:

```shell
docker-compose run --rm test
```

Before pushing a PR please run 

```shell 
docker-compose run --rm lint 
docker-compose run --rm shellcheck
```

To validate the plugin configuration and check for any potential issues in the shell scripts

## Contributing

1. Fork the repo
2. Make the changes
3. Run the tests
4. Commit and push your changes
5. Send a pull request

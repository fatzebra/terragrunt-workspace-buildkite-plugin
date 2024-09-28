# Terragrunt Workspace Buildkite Plugin

Provides a standard pipeline for deploying terragrunt workspaces

The plugin generates a dynamic pipeline based on the modules discovered by terragrunt. 

The pipeline consists of:

- A block step which allows you to select the modules to apply. This is ordered based on how it will be applied
- A command step which will run a plan for each of the selected modules and provide the output
- A block to confirm you want to run apply
- A command step to run apply for each of the selected modules

By default all modules found by terragrunt will be included in the block step, however you can filter this by provided a list of allowed modules. 

If you have modules that are just made up of data components that provide information to your other modules you can specify these modules under the data_modules option, before running the plan or apply commands on the selected modules each of the data modules will be refreshed. This builds a local state file since modules without resources don't save their state in terraform.


## Example

Add the following to your `pipeline.yml`:

```yml
steps:
  - command: ~
    plugins:
      - roleyfoley/terragrunt-workspace#v1.0.0:
          name: "test"
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


## Configuration

### `module_dir` (Required, string)

The relative path to the directory where the terragrunt modules you want to run are in.

### `allowed_modules` (Optional, array)

A list of directory/module names that can be used as part of this plugin

### `data_modules` (Optional, array)

The directory names of the modules you want to run `terragrunt refresh` each time a plan or apply is run on the `modules` or `always_modules`. Sometimes you might have modules that only have data components that lookup passwords, parameters etc. Since these don't save there state to a backend you need to refresh them each time to get their outputs.

### `debug_pipeline_output` (Optional, string)

Writes the pipeline to the nominated output path

## Module Discovery 

Modules are discovered using the terragrunt command `terragrunt output-module-groups` during a post-command hook, so if you don't have terragrunt installed on your agent and instead use the docker or docker-compose plugins this will fail to run. 

To get around this we can also read the module groups output from a meta-data key. To do this in the command that the plugin belongs to add this command to set the meta-data key. 

```
buildkite-agent meta-data set terragrunt-workspace-module-groups "$(terragrunt output-module-groups --terragrunt-working-dir <the configured module_dir for the plugin>)
```

## Developing

To run the tests:

```shell
docker-compose run --rm tests
```

## Contributing

1. Fork the repo
2. Make the changes
3. Run the tests
4. Commit and push your changes
5. Send a pull request
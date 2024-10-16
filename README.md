# fleet_package_with_variants

An example fleet package that can be rolled out across multiple environments.

## Setup

1. Define base package in `./base`. This example uses an nginx deployment.
2. Configure overlays in `./overlays`. These define the variants between environments. In this example, we set the project name as a label on the nginx deployment.
3. Configure the build targets in `./build`. Each `*.yaml` file will be matched in alphabetical order from the `deploy-fleet-package.sh` script. This dictates the sequencing. 

## Usage

1. Run `./generate.sh` to create the package. This script creates a package per overlay and can be matched by the build targets.
2. Commit changes and push latest changes to git
3. `cd build`
4. `./deploy-fleet-package.sh v1.0.20`. Change `v1.0.20` to a unique new version for this package. 
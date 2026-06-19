# Execute analysis script in container

Execute analysis script in container

## Usage

``` r
run_script(script_path, container_cmd = "docker-script")
```

## Arguments

- script_path:

  Path to R script

- container_cmd:

  Make target that runs the script in the container (default:
  "docker-script"). The target receives the script via the SCRIPT make
  variable.

## Value

Logical indicating success

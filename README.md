# Make a ZIP file for a release

## Introduction
This is designed to be used in GitHub Actions.  It allows you to quickly create a ZIP file with files and/or directories in it.

### Why another ZIP file creator Action?!

The main reason is for flexibility.  Many of the existing Actions I looked at didn't allow for renaming files, didn't support wildcards, or something that I was looking to use.  It was easy enough to write a new Action for this.

## Inputs
| Input | Type | Description |
|-------|------|-------------|
| `config_file` | string | The name of the JSON config file.  Default: `release_files.json`. |
| `fail_on_missing_file` | bool | Whether or not the Action should fail if a source file is missing (not found).  Default: `false`. |
| `overwrite_dst` | string | Should the ZIP file be overwritten?  Default: `true`. |

## Outputs
| Output | Type | Description |
|-------|------|-------------|
| `zip_files` | string | All ZIP files created. |
| `missing_files` | string | All missing files (if any). |
    
## Usage
Coming soon...

## Copyright Notice
Copyright (c) 2021 Oracle and/or its affiliates.
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
| `github_token` | string | The token used to interact with the GitHub API.  Usually use `secrets.GITHUB_TOKEN`. |

## Outputs
| Output | Type | Description |
|-------|------|-------------|
| `zip_files` | string | All ZIP files created. |
| `missing_files` | string | All missing files (if any). |
    
## Usage
This reads a JSON config file, which tells what ZIP file(s) to create.  Here's a sample:

```
[
  {
    "action": "create_zip",
    "file_name": "awesome_zip.zip",
    "files": [
      {
        "src_pattern": "*.tf"
      },
      {
        "src": "orm/provider.tf",
        "dst": "provider.tf"
      },
      {
        "src": "schema.yaml"
      },
      {
        "src": "orm",
        "recursive": true
      }
    ]
  },
  {
    "action": "upload_file",
    "file_name": "awesome_zip.zip"
  }
]
```

Config file options:

| Parameter | Description |
|-----------|-------------|
| `action` | The type of action.  `create_zip` and `upload_file` is supported now. |
| `file_name` | The name of the ZIP file to be created (`create_zip`) or uploaded to the release (`upload_file`). |
| `files` | Each ZIP file may have one or more files inside it. |

Inside of the `files` list attribute, it allows for `src` or `src_pattern` to specify the source file.  These accept files or directories to be given.

If you'd like to overwrite the destination filename (in the ZIP), specify `dst`.  This only works with `src` (not `src_pattern`).

`recursive` is whether or not all directory contents should be copied.  Default: `true`.

Note that you can create multiple ZIP files from a single run... simply have multiple `create_zip` actions in the config file.

## Copyright Notice
Copyright (c) 2021 Oracle and/or its affiliates.
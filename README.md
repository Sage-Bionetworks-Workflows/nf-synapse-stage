# nf-synstage: Stage Synapse Files

## Purpose

The purpose of this Nextflow workflow is to automate the process of staging Synapse files in an accessible location (_e.g._ an S3 bucket). In turn, these staged files can be used as input for a general-purpose (_e.g._ nf-core) workflow that doesn't contain Synapse-specific steps for downloading data. This workflow is intended to be run first in preparation for other data processing workflows.

Briefly, `nf-synstage` achieves this automation as follows:

1. Extract all Synapse URIs (_e.g._ `syn://syn28521174`) from a given text file
2. Download the corresponding files from Synapse in parallel
3. Replace the Synapse URIs in the text file with their staged locations
4. Output the updated text file so it can serve as input for another workflow

## Quickstart

The examples below demonstrate how you would stage Synapse files in an S3 bucket called `example-bucket`, but they can be adapted for other storage backends.

1. Prepare your input text file containing the Synapse URIs. For example, the following CSV file follows the format required for running the [`nf-core/rnaseq`](https://nf-co.re/rnaseq/latest/usage) workflow.

    **Example:** Uploaded to `s3://example-bucket/input.csv`

    ```text
    sample,fastq_1,fastq_2,strandedness
    foobar,syn://syn28521174,syn://syn28521175,unstranded
    ```

2. Create a user secret called `SYNAPSE_AUTH_TOKEN` in Tower with a [personal access token](https://www.synapse.org/#!PersonalAccessTokens:). For more details, check out the [Authentication](#authentication) section.

    **Example:** If using Nextflow Tower hosted by Sage Bionetworks, create a secret [here](https://tower.sagebionetworks.org/secrets).

3. Prepare your parameters file. For more details, check out the [Parameters](#parameters) section. Only the `input` parameter is required.

    **Example:** Stored locally as `./params.yml`

    ```yaml
    input: "s3://example-bucket/input.csv"
    ```

4. Launch workflow using the [Nextflow CLI](https://nextflow.io/docs/latest/cli.html#run), the [Tower CLI](https://help.tower.nf/latest/cli/), or the [Tower web UI](https://help.tower.nf/latest/launch/launchpad/).

    **Example:** Launched using the Tower CLI

    ```console
    tw launch sage-bionetworks-workflows/nf-synstage --params-file=./params.yml
    ```

5. Retrieve the output file, which is stored in a `synstage/` subfolder relative to the input file. The Synapse URIs have been replaced with their staged locations. This file can now be used as the input for other workflows.

    **Example:** Downloaded from `s3://example-bucket/synstage/input.csv`

    ```text
    sample,fastq_1,fastq_2,strandedness
    foobar,s3://example-scratch/synstage/syn28521174/foobar.R1.fastq.gz,s3://example-scratch/synstage/syn28521175/foobar.R2.fastq.gz,unstranded
    ```

## Authentication

Downloading files from Synapse requires the workflow to be authenticated. The workflow currently supports two authentication methods:

- **(Preferred)** Create a secret called `SYNAPSE_AUTH_TOKEN` containing a Synapse personal access token using the [Nextflow CLI](https://nextflow.io/docs/latest/secrets.html) or [Nextflow Tower](https://help.tower.nf/latest/secrets/overview/).
- Provide a Synapse configuration file containing a personal access token (see example above) to the `synapse_config` parameter. This method is best used if Nextflow/Tower secrets aren't supported on your platform. **Important:** Make sure that your `synapse_config` file is not stored in a directory that will be indexed on or uploaded to Synapse.

### Personal access tokens

You can generate a Synapse personal access token using [this dashboard](https://www.synapse.org/#!PersonalAccessTokens:).

## Parameters

Check out the [Quickstart](#quickstart) section for example parameter values.

- **`input`**: (Required) A text file containing Synapse URIs (_e.g._ `syn://syn28521174`). The text file can have any format (_e.g._ a single column of Synapse URIs, a CSV/TSV sample sheet for an nf-core workflow).

- **`outdir`**: (Optional) An output location where the Synapse files will be staged. Currently, this location must be an S3 prefix. By default, these downloaded files will be stored in a subfolder called `synstage` in the work directory.

- **`synapse_config`**: (Optional) A [Synapse configuration file](https://python-docs.synapse.org/build/html/Credentials.html#use-synapseconfig) containing authentication credentials.

## Known Limitations

- The only way for the workflow to download Synapse files is by listing Synapse URIs in a file. You cannot provide a list of Synapse IDs or URIs to a parameter.
- The workflow doesn't check if newer versions exist for the files associated with the Synapse URIs. If you need to force-download a newer version, you should manually delete the staged version.

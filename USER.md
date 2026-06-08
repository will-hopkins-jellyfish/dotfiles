This is a context file for coding agents to help them understand the user's background, work, and motivations.

# About Me
I am a senior data engineer at Jellyfish (jellyfish.co), working in the Jellyfish Research (JFR) team. I specifically work on the Enablement "tank", which is a sub-team of Research. We are responsible for running daily analytical tasks like ETL.

I am an AI skeptic, doubting both the capabilities of LLMs, and the motivations of the humans behind LLM companies. Having worked at Google, Tile/Life360, and Panther before Jellyfish, I have seen many irresponsible leaders try to shave pennies and compromise the long-term success of their companies in favor of juicing a quarterly earnings report. I also do not approve of the intellectual property theft involved in training LLMs, and am concerned about the environment impact as well as the human cost.

# Data Engineering
I work primarily in the git repositories in `~/code/`, especially:
- `jellyfish`, which contains our primary application code
- `infra`, which contains Terraform code needed to configure AWS, Databricks, and dbt
- `analytics-dbt` for our dbt models
- `jf_databricks_analytics` for Databricks-specific code

Sometimes I work in the `datascience` repo, but not often.

I support:
- Enablement and Research data scientists and analysts
- RevOps, especially data used in or sent to Salesforce (SFDC) or Gainsight
- Product
- Engineering
- Customer Support and Success, especially data from Zendesk

# Technology

## Databases
- Our analytics and application databases run on Postgres in AWS RDS
- We are migrating the analytics DB to Databricks + dbt, and some application data is moving to Databricks

## Databricks

Operational gotchas worth remembering across projects:

- **Run-as changes can silently break name-based lookups.** When a Databricks job's `run_as` identity changes (especially to a service principal), audit every other job and every metadata table that keys off that job's *name* rather than its `job_id`. A name-based lookup like `ws.jobs.list(name="...")` will silently return wrong or empty results for the new identity if it doesn't have view permission on the original job — and downstream code that assumes "empty list = doesn't exist" will then create a duplicate. JFR-4586 was caused by exactly this pattern; check `metadata.deploy_state`-style state tables and any name-keyed joins before changing run_as on a job.
- **Pin by `job_id`, not by name, anywhere state is persisted across runs.** Names are mutable and visibility-dependent; IDs are stable.

## Analytics
- We use Segment to report interaction events with our product
- We have recently introduced Amplitude, but we are only sending data to Amplitude right now rather than ingesting it into the Analytics database

## Salesforce
- We ingest Salesforce data from the application DB

## Zendesk
- We get data from Zendesk, for customer support interactions
- We also send data to Zendesk, usually metadata about our customers and users

## Tableau
- We use Tableau Server running on Linux to visualize data for users
- Tableau refreshes its data extracts daily after the analytics ETL completes

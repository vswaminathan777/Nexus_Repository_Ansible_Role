# nexus_repo_pro role

This role installs Nexus Repository Pro, configures external PostgreSQL, enables HA mode, waits for health after restart, and optionally bootstraps shared file or S3 blob stores through the Nexus REST API.

## Notes

- This role does not provision PostgreSQL, the load balancer, or shared storage.
- For HA, all nodes should share the same PostgreSQL database and shared blob stores.
- Blob store bootstrap uses `run_once: true` so it runs once for the cluster.
- Upgrade runs are gated by `nexus_upgrade_enabled`.

# module: access-point

Creates an S3 Files access point for scoped file system access.

**Lambda requires an access point** — it cannot mount a file system by ID alone. The access point enforces a POSIX UID/GID and exposes a scoped root directory as `/` inside the Lambda execution environment.

Default values match the console auto-created access point: UID/GID `1000/1000`, root directory `/`.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

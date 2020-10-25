postgres-backup-restore
-----------------------

Manage Restoring a Postgres Backup.

> NOTE: This should ideally be used for sql backups or you'll need to restore the roles required when using `-Fc` | `-Fd` | `-Ft` based backups.

References: 
- https://www.postgresql.org/docs/9.3/app-pgdump.html


### Usage

- Create a backup using
```shell script
$ cd [project_root]
$ mkdir backups
$ pg_dump -O -s -f backups/backup.sql $DATABASE_URL
```

Add action to .github/workflows

```yaml
...
    steps:
      - uses: actions/checkout@v2
      - name: Postgres Backup Restore
        uses: tj-actions/postgres-backup-restore@v1
        with:
          database_url: "postgres://test_user:test_user_password@localhost:5432/testdb"
          backup_file: "backups/backup.sql"
```


## Inputs

|   Input       |    type    |  required     |  default             | 
|:-------------:|:-----------:|:-------------:|:---------------------:|
| token         |  `string`   |    `false`    | `${{ github.token }}` |



* Free software: [MIT license](LICENSE)

Features
--------

* TODO


Credits
-------

This package was created with [Cookiecutter](https://github.com/cookiecutter/cookiecutter).



Report Bugs
-----------

Report bugs at https://github.com/tj-actions/postgres-backup-restore/issues.

If you are reporting a bug, please include:

* Your operating system name and version.
* Any details about your workflow that might be helpful in troubleshooting.
* Detailed steps to reproduce the bug.

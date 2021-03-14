[![CI](https://github.com/tj-actions/pg-restore/actions/workflows/test.yml/badge.svg)](https://github.com/tj-actions/pg-restore/actions/workflows/test.yml)

postgres-restore
----------------

Restore a postgres service container using a sql backup file with psql.

References: 
- https://www.postgresql.org/docs/9.3/app-pgdump.html

> NOTE: This only supports sql backups.


### Usage

- Create a backup using
```shell script
$ cd [project_root]
$ mkdir backups
$ pg_dump -O -f backups/backup.sql $DATABASE_URL
```

Add action to .github/workflows

```yaml
...
    steps:
      - uses: actions/checkout@v2
      - name: Postgres Backup Restore
        uses: tj-actions/postgres-restore@v3
        with:
          database_url: "postgres://test_user:test_password@localhost:5432/test_db"
          backup_file: "backups/backup.sql"
```


## Inputs

|   Input       |    type    |  required     |  default             | 
|:-------------:|:-----------:|:-------------:|:---------------------:|
| database_url         |  `string`   |    `true`    |  |
| backup_file         |  `string`   |    `true`    |  |



* Free software: [MIT license](LICENSE)


Credits
-------

This package was created with [Cookiecutter](https://github.com/cookiecutter/cookiecutter).



Report Bugs
-----------

Report bugs at https://github.com/tj-actions/postgres-restore/issues.

If you are reporting a bug, please include:

* Your operating system name and version.
* Any details about your workflow that might be helpful in troubleshooting.
* Detailed steps to reproduce the bug.

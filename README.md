[![CI](https://github.com/tj-actions/pg-restore/actions/workflows/test.yml/badge.svg)](https://github.com/tj-actions/pg-restore/actions/workflows/test.yml) [![Update release version.](https://github.com/tj-actions/pg-restore/actions/workflows/sync-release-version.yml/badge.svg)](https://github.com/tj-actions/pg-restore/actions/workflows/sync-release-version.yml)

[pg-restore](https://www.postgresql.org/docs/9.3/app-pgdump.html)
------------

Restore a postgres service container using a sql backup file with psql.

> NOTE: This only supports sql backups.


### Usage

- Create a backup using
```shell script
$ cd [project_root]
$ mkdir backups
$ pg_dump -O -f backups/backup.sql $DATABASE_URL
```

See: https://github.com/tj-actions/pg-dump

Add action to .github/workflows

```yaml
...
    steps:
      - uses: actions/checkout@v2
      - name: Postgres Backup Restore
        uses: tj-actions/pg-restore@v4.5
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

If you feel generous and want to show some extra appreciation:

[![Buy me a coffee][buymeacoffee-shield]][buymeacoffee]

[buymeacoffee]: https://www.buymeacoffee.com/jackton1
[buymeacoffee-shield]: https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png



Credits
-------

This package was created with [Cookiecutter](https://github.com/cookiecutter/cookiecutter).



Report Bugs
-----------

Report bugs at https://github.com/tj-actions/pg-restore/issues.

If you are reporting a bug, please include:

* Your operating system name and version.
* Any details about your workflow that might be helpful in troubleshooting.
* Detailed steps to reproduce the bug.

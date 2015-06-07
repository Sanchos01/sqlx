Sqlx
====

Usage 
- configure your mysql pools and mysql timeout (look example in ./config/config.exs)
- execute awesome mysql queries (look examples in tests)

Public functions

```
Sqlx.prepare_query(str, args)
Sqlx.exec(query, args, pool \\ :mysql) 
Sqlx.insert(lst, keys, tab, pool \\ :mysql)
Sqlx.insert_ignore(lst, keys, tab, pool \\ :mysql)
Sqlx.insert_duplicate(lst, keys, uniq_keys, tab, pool \\ :mysql)
```

Note : for execution tests run mysql server and execute

```
mysql < ./priv/table_defs.sql
```
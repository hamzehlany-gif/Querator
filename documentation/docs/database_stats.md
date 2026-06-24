### Match/Players Stats and Data

MatchZy comes with a default database (SQLite), which configures itself automatically. MySQL Database can also be used with MatchZy!
Currently we are using 3 tables, `querator_stats_matches`, `querator_stats_maps` and `querator_stats_players`.
 
As their names suggest, `querator_stats_matches` holds the data of every match, like matchid, team names, scores, etc.
`querator_stats_maps` stores data of every map in a match.
Whereas, `querator_stats_players` stores data/stats of every player who played in that match. It stores data like matchid, kills, deaths, assists, and other important stats!

### Using MySQL Database with MatchZy

To use MySQL Database with MatchZy, open `csgo/cfg/Querator/database.json` file. It's content will be like this:
```json
{
    "DatabaseType": "SQLite",
    "MySqlHost": "your_mysql_host",
    "MySqlDatabase": "your_mysql_database",
    "MySqlUsername": "your_mysql_username",
    "MySqlPassword": "your_mysql_password",
    "MySqlPort": 3306
}
```
Here, change the `DatabaseType` from `SQLite` to `MySQL` and then fill-up all the other details like host, database, username, etc.
MySQL Database is useful for those who wants to use a common database across multiple servers!

### CSV Stats
Once a match is over, data is pulled from the database and a CSV file is written in the folder:
`csgo/Querator_Stats`. This folder will contain CSV file for each match (file name pattern: `match_data_map{mapNumber}_{matchId}.csv`) and it will have the same data which is present in `querator_stats_players`.

There is a scope of improvement here, like having the match score in the CSV file or atleast in the file name patter. I'll make this change soon!

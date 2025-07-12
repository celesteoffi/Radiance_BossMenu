BossMenu 

Configuration Facile et simple

- F6 
- Whitlist jobs

## Config.lua :
```
-- Liste blanche des jobs autorisés
-- bossGrade = ID du grade ayant toutes les permissions
Config = {}

Config.WhitelistedJobs = {
    Gouvernement      = { bossGrade = 4 },
    LSPD      = { bossGrade = 4 },
    SAMS      = { bossGrade = 5 },
    USSS      = { bossGrade = 1 },
    HLS      = { bossGrade = 9 },
    -- Ajoute autant de jobs que tu veux :
    -- jobName = { bossGrade = gradeId }
}
```

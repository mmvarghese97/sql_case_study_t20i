-- identify matches played between any 2 specific teams and their results
SELECT
	*
FROM 
	t20i
WHERE 
	(team1 = 'Australia' and team2 = 'India') or (team2 = 'Australia' and team1 = 'India');

-- team with highest number of wins in 2024
SELECT 
	winner,COUNT(*) as no_of_wins
FROM 
	t20i
WHERE 
	EXTRACT(year from matchdate) = 2024
GROUP BY winner
ORDER BY no_of_wins desc
LIMIT 1;

-- rank teams based on total number of wins in 2024
SELECT 
	winner,COUNT(*) as no_of_wins,DENSE_RANK() OVER (ORDER BY COUNT(*) DESC)
FROM 
	t20i
WHERE 
	EXTRACT(year from matchdate) = 2024 and winner not in ('tied', 'no result')
GROUP BY winner;

-- sort teams according to highest average runs margin wins
SELECT
	winner,ROUND(AVG(SUBSTRING(margin,1,POSITION(' ' IN margin)-1)::NUMERIC),2)  as average_runs_margin
FROM 
	t20i
where
	margin like '%runs'
GROUP BY winner
ORDER BY average_runs_margin DESC;

--list all margins where winning margin > average margin across all matches
with runs_margin as 
	(SELECT ROUND(AVG(SUBSTRING(margin,1,POSITION(' ' IN margin)-1)::NUMERIC),2)  as average_runs_margin
		FROM t20i
		WHERE margin like '%runs'),

wickets_margin as
	(SELECT ROUND(AVG(SUBSTRING(margin,1,POSITION(' ' IN margin)-1)::NUMERIC),2)  as average_wickets_margin
		FROM t20i
		WHERE margin like '%wickets')

SELECT 
	team1,team2,winner,margin
FROM 
	t20i 
where 
	margin like '%runs' and SUBSTRING(margin,1,POSITION(' ' IN margin)-1)::NUMERIC > (SELECT average_runs_margin from runs_margin)
UNION ALL
SELECT 
	team1,team2,winner,margin
FROM 
	t20i 
where 
	margin like '%wickets' and SUBSTRING(margin,1,POSITION(' ' IN margin)-1)::NUMERIC > (SELECT average_wickets_margin from wickets_margin)
ORDER BY 
	margin asc;

-- team with most wins when win by wickets
SELECT *
FROM
(
	SELECT winner,COUNT(*) as  no_of_wins,rank() OVER (order by COUNT(*) desc) as rk
	FROM t20i
	WHERE margin like '%wickets'
	and winner not in ('tied','no result')
	GROUP BY winner
	ORDER BY no_of_wins desc
)
WHERE rk = 1;

-- function to get head to head record between 2 selected teams

CREATE or replace  function matchup_result(team_1 text,team_2 text)
RETURNS table (winner TEXT,total_wins BIGINT)
LANGUAGE plpgsql
AS
$$

BEGIN
	RETURN query
	SELECT 
		t.winner::text,COUNT(*) 
	FROM t20i as t
		WHERE 
		( t.team1 = team_1 AND t.team2 = team_2)
		OR
		(t.team1 = team_2 AND t.team2 = team_1)
	GROUP BY t.winner;

END;
$$

SELECT * FROM matchup_result('England','Australia');

-- month with highest t20 matches played 

SELECT to_char(matchdate,'Month') as month,COUNT(*) as  matches_played
FROM t20i
GROUP BY month
ORDER BY matches_played desc
LIMIT 1

-- for each team how many matched did they play and win percentage

with no_of_games_played AS
(
SELECT team,COUNT(*) as games_played
FROM 
(SELECT team1 as team FROM t20i
UNION ALL
SELECT team2 as team from t20i)
GROUP BY team
),

no_of_wins AS
(
SELECT winner,cOUNT(*) as wins
FROM t20i
GROUP BY winner
)

SELECT team,games_played,wins,
CASE
WHEN wins is not null then ROUND((wins::numeric/games_played::numeric)*100,2) || '%'
ELSE '0%'
END AS win_percentage
FROM no_of_games_played ng
LEFT JOIN no_of_wins nw
ON ng.team = nw.winner

ORDER BY 
CASE
WHEN wins is not null then ROUND((wins::numeric/games_played::numeric)*100,2) || '%'
ELSE '0%'
END desc

-- teams with most wins per ground

SELECT *
FROM 
(
SELECT winner,ground,COUNT(*) as no_wins,RANK() OVER (PARTITION BY ground ORDER BY count(*) desc) as rk
FROM t20i
GROUP BY ground,winner
) t1
WHERE rk = 1 and winner not in ('tied','no result')
ORDER BY ground
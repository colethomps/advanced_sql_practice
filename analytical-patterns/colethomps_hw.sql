--Week 4 Applying Analytical Patterns
--#1
WITH prev_year as (
select * from player_seasons
where season = '2000'),
    curr_year as (
        select * from player_seasons
                 where season = '2001'
    )
SELECT
    COALESCE(p.player_name,c.player_name) as player_name,
    COALESCE(p.season,c.season) as first_season,
    COALESCE(c.season,p.season) as last_season,
    CASE
        WHEN COALESCE(p.season,c.season) = c.season THEN 'NEW'
        WHEN p.season = c.season -1 THEN 'Continued Playing'
        WHEN p.season < c.season -1 THEN 'Returned from Retirement'
        WHEN COALESCE(c.season,p.season) = p.season THEN 'Retired'
        ELSE 'Stayed Retired' END as state_tracking
FROM
    curr_year c
    FULL OUTER JOIN prev_year p
    ON c.player_name = p.player_name

--#2-------------------------------------------
with deduped as (
select
            g.season,
            team_abbreviation as team,
            gd.player_name,
            gd.game_id,
            coalesce(gd.pts, 0) as game_pts,
            case
                when gd.team_id = g.team_id_home THEN 1
                WHEN gd.team_id = g.team_id_away THEN 0
                ELSE null
	    	end as winner,
	    	ROW_NUMBER() OVER(PARTITION BY gd.game_id, gd.player_id ORDER BY g.game_date_est) as player_row_num,
	    	ROW_NUMBER() OVER(PARTITION BY gd.game_id, gd.team_id ORDER BY g.game_date_est) as team_row_num
        from game_details gd
        left join games g on gd.game_id = g.game_id
),
    stats_agg as (
    	select
    		season,
    		team,
    		player_name,
    		sum(game_pts) as total_pts,
    		count(winner) as total_wins
    	from deduped
    	where player_row_num=1
    	group by
    		grouping sets (
    			(player_name, team),
    			(player_name, season),
    			(team)
    		)
    )

-- select player_name, team, MAX(total_pts) from stats_agg
-- where player_name is not null
-- group by team, player_name
-- order by MAX(total_pts) DESC
--
-- LeBron James,CLE,28314


-- select player_name,season, MAX(total_pts) from stats_agg
-- where season is not null
-- group by season, player_name
-- order by MAX(total_pts) DESC
--
-- Kevin Durant,2013,3265


-- select team,sum(winner) from deduped
-- where team_row_num = 1
--                           group by team
--
-- LAL,961

--#3-------------------------------------------

with deduped as (
select
            g.season,
            team_abbreviation as team,
            gd.game_id,
            game_date_est,
            case
                when gd.team_id = g.team_id_home THEN 1
                WHEN gd.team_id = g.team_id_away THEN 0
                ELSE null
	    	end as winner,
	    	ROW_NUMBER() OVER(PARTITION BY gd.game_id, gd.team_id ORDER BY g.game_date_est) as team_row_num
        from game_details gd
        left join games g on gd.game_id = g.game_id
)
select team,
       game_date_est,
       sum(winner) OVER (PARTITION BY team ORDER BY game_date_est ROWS BETWEEN 89 PRECEDING AND CURRENT ROW)
from deduped
where team_row_num = 1
Order by sum(winner) OVER (PARTITION BY team ORDER BY game_date_est ROWS BETWEEN 89 PRECEDING AND CURRENT ROW) DESC

--CHI,2013-01-23,56

with count_pts as (
select
            g.season,
            player_name,
            gd.game_id,
            game_date_est,
            pts,
            CASE WHEN pts > 10 THEN 1
                ELSE 0 END as over_10_pts,
	    	ROW_NUMBER() OVER(PARTITION BY gd.player_id, gd.game_id ORDER BY g.game_date_est) as player_row_num
        from game_details gd
        left join games g on gd.game_id = g.game_id
), dedupe as (
SELECT season,
       player_name,
       game_id,pts,
       player_row_num,
       game_date_est,
       over_10_pts,
       row_number() over (partition by player_name order by game_date_est) as id
FROM count_pts
where player_row_num = 1
and pts is not null
and player_name = 'LeBron James'
), gap as (
select player_name,game_date_est, id,
       over_10_pts,
       row_number() over (partition by over_10_pts order by game_date_est ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) - id as gap,
       id,
        row_number() over (partition by over_10_pts order by game_date_est ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
from dedupe
where over_10_pts = 1
order by game_date_est DESC)
select player_name,
       count(1) as streak_over_10pts
from gap
group by player_name, gap
order by count(1) DESC

--LeBron James,292

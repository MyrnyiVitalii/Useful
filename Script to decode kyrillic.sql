CREATE OR REPLACE FUNCTION pg_temp.decode_url_part(p varchar) RETURNS varchar AS $$
SELECT convert_from(CAST(E'\\x' || string_agg(CASE WHEN length(r.m[1]) = 1 THEN encode(convert_to(r.m[1], 'SQL_ASCII'), 'hex') ELSE substring(r.m[1] from 2 for 2) END, '') AS bytea), 'UTF8')
FROM regexp_matches($1, '%[0-9a-f][0-9a-f]|.', 'gi') AS r(m);
$$ LANGUAGE SQL IMMUTABLE STRICT;


with all_ads_data as (
	select ad_date, url_parameters, coalesce(spend, 0) as spend,  coalesce(impressions, 0) as impressions,  coalesce(reach, 0) as reach,  coalesce(clicks, 0) as clicks,  coalesce(leads, 0) as leads,  coalesce(value, 0) as value
	from facebook_ads_basic_daily fabd
	
	union all
	
	select ad_date, url_parameters, coalesce(spend, 0), coalesce(impressions, 0), coalesce(reach, 0), coalesce(clicks, 0), coalesce(leads, 0), coalesce(value, 0)
	from google_ads_basic_daily gabd
)

select 
	ad_date as ad_month,
	case
		when lower(substring(url_parameters, 'utm_campaign=([^\&]+)')) != 'nan' then decode_url_part(lower(substring(url_parameters, 'utm_campaign=([^\&]+)')))
	end as utm_campaign,
	sum(spend) as total_spend, 
	sum(impressions) as total_impressions,
	sum(clicks) as total_clicks,
	sum(value) as total_value,
	case 
		when sum(clicks) > 0 then 1000*sum(spend)/sum(clicks)
	end as cpc,
	case 
		when sum(impressions) > 0 then 1000*sum(spend)/sum(impressions)
	end as cpm,
	case 
		when sum(impressions) > 0 then sum(clicks)::numeric/sum(impressions)
	end as ctr,
	case 
		when sum(spend) > 0 then sum(value)::numeric/sum(spend)
	end as romi
from all_ads_data aad 
group by 1,2;
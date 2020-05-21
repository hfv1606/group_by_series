/*
 *   PGPASSWORD=gbys psql -U gbys -d gbys -p 5433 -h dev.visserdata.nl -f query.sql -v ts=1
 *   PGPASSWORD=gbys psql -U gbys -d gbys -p 5433 -h dev.visserdata.nl -f query.sql -v ts=2
 *   PGPASSWORD=gbys psql -U gbys -d gbys -p 5433 -h dev.visserdata.nl -f query.sql -v ts=4
 *
 *   Deze query bepaalt per ggdregio welke aaneensluitende postcode ranges hier bij horen.
 *    * q1: sorteer de lijst naar postcode
 *          bepaal per record de regio van het vorige record
 *          bepaal per record de regio van het volgende record
 *    * q2: er begint  een postcode range: als de regio anders is dan de regio van het vorige record of als er geen vorig record is
 *          er eindigt een postcode range: als de regio anders is dan de regio van het volgende record of als er geen volgend record is
 *          selecteer alleen de regels waar een postcode range begint of eindigt
 *    * q3: voeg de eind postcode toe aan het record met een start postcode en zonder eindpostcode
 *    * q4: verwijder de de records met enkel een eind postcodes
 */

\echo
\echo TESTDATA for: :ts
\echo
select    postcode
,         regio
from      postcodes   as pc
where     test_scenario & :ts > 0 -- 1,2,4
order by  pc.postcode
;

\echo TESTRESULTS for: :ts
\echo
with q1 as (
        select    lag(regio)  over (partition by 'all' order by postcode) as lag_regio  -- de vorige regio
        ,         lead(regio) over (partition by 'all' order by postcode) as lead_regio -- de volgende regio
        ,         postcode
        ,         regio
        from      postcodes   as pc
        where     test_scenario & :ts > 0 -- 1,2,4
        order by  pc.postcode
)
, q2 as (
    select   case when regio <> coalesce(lag_regio ,'FIRST') then postcode end as startpc
    ,        case when regio <> coalesce(lead_regio,'LAST' ) then postcode end as eindpc
    ,        *
    from     q1
    where    regio <> coalesce(lag_regio ,'FIRST') -- alleen eerste postcodes
    or       regio <> coalesce(lead_regio,'LAST' ) -- en laatste postcodes van een serie
        order by postcode
)
, q3 as (
    -- als er geen laatste postcode is neem de laatste postcode van de volgende regel
        select case
                   when
                       startpc is not null and eindpc is null then
                           lead(eindpc) over (partition by regio order by postcode)
                   when
                       startpc is not null and eindpc is not null then
                           eindpc
               end as eindpc2
        ,      *
        from   q2
        order by postcode
)
select   startpc
,        eindpc2 as eindpc
,        regio
from     q3
where    startpc is not null  -- regels met alleen een eind postcodes kunnen nu weg
order by startpc
,        regio
;

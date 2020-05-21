% Group by series
#
Van een klant kreeg ik het volgende probleem voorgeschoteld.

Wij hebben Nederland ingedeeld in verschillende regio's. 
In ons transactiesysteem hebben we de beschikking over een postcode maar niet over de bijbehorende regio. 
Er is een extern systeem waar we de regio die bij een postcode hoort, kunnen opzoeken.  
Maar door de grote hoeveelheid transacties die we verwerken en de snelheid waarmee deze verwerkt moeten worden, 
is het geen optie om voor elke transactie deze lookup service te bevragen. 
Ook willen we geen kopie hebben van de postcode tabel in ons systeem met 400.000 records. 
Daarom willen we een kleine lookup tabel waarin per regio de postcodeseries vermeld staan. 
Met ander woorden zet de linker tabel om in de rechter tabel 

<table>
<tr><th>Postcode tabel</th><th></th><th>Postcode serie tabel</th></tr>
<tr>
<td>

| Postcode | Regio     | 
|----------|-----------|
| 5432AN   | Regio I   |
| 5432AO   | Regio I   |
| 5432AP   | Regio II  |
| 5432AQ   | Regio II  |
| 5432AR   | Regio I   |
| 5432AS   | Regio III |
</td><td>

</td><td>

| Postcode serie  | Regio     |
|-----------------|-----------|
| 5432AN - 5432AO | Regio I   |
| 5432AP - 5432AQ | Regio II  |
| 5432AR - 5432AR | Regio I   |
| 5432AS - 5432AS | Regio III |
|  - |  - |
|  - |  - |
</td>
</tr>
</table>


In eerst instantie dacht ik: gewoon ``group by regio`` en dan ``min(postcode)`` en ``max(postcode)`` berekenen. 
Maar dat was iets te snel gedacht. De postcode reeks loopt natuurlijk dwars door de regio's heen. 
Ook een eenvoudige oplossing met ``partion by`` bleek niet mogelijk. 
Een vraag die intuïtief met SQL lijkt te kunnen, bleek niet eenvoudig met standaard SQL functionaliteit te kunnen.
SQL kan prima een aggregatie uitvoeren op de data als het aggregatieniveau maar van te voren bekend is. 
Hier was het aggregatieniveau vooraf onbekend en moest uit de data afgeleid worden. 
Deze vraag kan eenvoudig met procedurele code opgelost worden. Zie de python code onderaan dit artikel. 

In dit artikel zal ik uitleggen hoe dit probleem met SQL opgelost kan worden.

Laten we het probleem eens visueel maken. 
De postcodes (in zwart) kennen een volgorde die door de regio's (in groen) worden onderverdeeld in kleinere series (in rood)
Wat we willen weten is: wat zijn de postcodes aan het begin en het eind van de korte series? 
En in werke regio liggen ze? 

[postcode_regions.gv.png](postcode_regions.gv.png)

Er is geen SQL-functie waarmee dit in één keer declaratief bepaald kan worden. Maar het kan wel met een query. 
Daarvoor zullen de volgende stappen uitgevoerd moeten worden:
* sorteer de lijst van alle postcode en regios op postcode   
* Bepaal het eerst en laatste postcode van een postcodeserie binnen een regio
  * eerste: de regio van de vorige postcode is anders
  * laatste: de regio van de volgende postcode is anders
* verwijder tussenliggende postcodes
* voeg eerste en laatste postcodes samen in één record

Er zijn twee bijzonderheden waarmee rekening gehouden moet worden:
* de allereerste postcode kent geen vorige postcode
* de allerlaatse postcode in de lijst kent geen volgende postcode
* er zijn postcode series waarbij de eerste postcode gelijk is aan de laatste.

De code komt er dan zo uit te zien
```sql
with q1 as (
	select    lag(regio)  over (partition by 'all' order by postcode) as lag_regio  -- de vorige regio
	,         lead(regio) over (partition by 'all' order by postcode) as lead_regio -- de volgende regio
	,         postcode
	,         regio
	from      postcodes   as pc
	where     test_scenario & 4 > 0 -- 1,2,4
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
```


## Testen
Om deze code goed te kunnen testen hebben we een testdataset nodig waarin alle mogelijke varianten zitten.
Hoe bepaal je alle mogelijke varianten? 

De manier waarop de resultaten berekend worden is afhankelijk van de lengte van de postcodeseries. 
Bij series van 3 of meer postcode lang moeten de tussenliggende postcode verwijderd en 
de eerste en laatste postcode in de serie worden samengevoegd op één regel. 
Bij series van 2 postcodes hoeven er natuurlijk géén tussenliggende postcodes te worden verwijderd.
Bij series van 1 postcode hoeven er géén postcodes te worden verwijderd én hoeft er ook niets samengevoegd te worden op één regel.

|lengte|verwijderen <br> tussenliggende <br> records |samenvoegen <br> eerste en <br> laatse postcode|start met <br> allereerste <br> postcode|eindig met <br> allerlaatste <br> postcode
|------|:---------                                  :|:---------                                    :|---                      |---                      |   
|=1    |                                             |                                               |V                        |V                        |
|=2    |                                             |     V                                         |V                        |V                        |  
|\>3   |     V                                       |     V                                         |V                        |V                        |  

Er zijn twee verschillende regio's mogelijk. Regio's met één postcodeserie en regio's met twee of meer postcodeseries. 

Als we voor elke lengte een aparte test doen, kunnen we met een testdataset van 9 gevallen alle varianten testen.

|Postcode|Regio|321|
|--------|-----|---|
|AAAA01  |A    |111|
|AAAA02  |A    |110|
|AAAA03  |A    |100|
|AAAA04  |B    |111|
|AAAA05  |B    |110|
|AAAA06  |B    |100|
|AAAA07  |A    |111|
|AAAA08  |A    |110|
|AAAA09  |A    |100|

## SQL RFC
Intuïtief lijkt het alsof deze postcode serie per regio iets is wat simpel in SQL zou moeten kunnen. 
Helaas zit deze functionaliteit er nog niet in. Hoe zou de query er in de SQL van de toekomst uitzien.

```sql
select min_of_serie(postcode)
,      max_of_serie(postcode) 
,      count_of_serie(postcode) 
from postcodes
group by series of postcode over regio
;
```

##Procedurele oplossing
```python
import psycopg2
from psycopg2.extras import DictCursor

dsn = "host={} port={} dbname={} user={} password={}".format("dev.visserdata.nl", "5433", "groupbyseries", "groupbyseries", "groupbyseries")

for ts in (1, 2, 4):
    sql = "select postcode, regio from postcodes where test_scenario & {} > 0 order by postcode".format(ts)

    with psycopg2.connect(dsn, cursor_factory=DictCursor) as conn:
        with conn.cursor() as cur:
            print('testscenario: {}'.format(ts))
            cur.execute(sql)

            results = cur.fetchall()
            gbs = []

            for i, rec in enumerate(results):
                if i == 0 or rec['regio'] != results[i - 1]['regio']:
                    gbs_row = [rec['regio'], rec['postcode']]
                if i == len(results) - 1 or rec['regio'] != results[i + 1]['regio']:
                    gbs_row.append(rec['postcode'])
                    gbs.append(gbs_row)

            for g in gbs:
                print(g)
```


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
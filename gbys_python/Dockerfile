FROM python
RUN pip install psycopg2

WORKDIR work

COPY work/start.sh ./
RUN chmod +x ./start.sh

CMD ./start.sh
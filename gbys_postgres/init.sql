drop user if exists gbys cascade;
create user gbys password 'gbys';

drop database if exists gbys cascade;
create database gbys with owner gbys;

grant pg_read_server_files to gbys;


\c gbys

drop table if exists postcodes cascade;
create table postcodes (
 postcode varchar(6)
,regio  varchar(1)
,test_scenario int
);

insert into postcodes values
 ('AAAA01','A',7)
,('AAAA02','A',6)
,('AAAA03','A',4)
,('AAAA04','B',7)
,('AAAA05','B',6)
,('AAAA06','B',4)
,('AAAA07','A',7)
,('AAAA08','A',6)
,('AAAA09','A',4)
;

alter table postcodes owner to gbys
;

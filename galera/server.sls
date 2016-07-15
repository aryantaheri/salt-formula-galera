{%- if pillar.get('mysql', {}).server is defined  %}

{%- set server = pillar.mysql.server %}

{%- set mysql_connection_unix_socket = '/var/run/mysqld/mysqld.sock' %}
{%- set mysql_connection_db = 'mysql' %}
{%- set mysql_connection_charset = 'utf8' %}

{%- if pillar.galera.master is defined and pillar.galera.master.admin is defined %}
{%- set mysql_connection_config = pillar.galera.master.admin %}
{%- elif pillar.galera.slave is defined and pillar.galera.slave.admin is defined %}
{%- set mysql_connection_config = pillar.galera.slave.admin %}
{%- endif %}

{%- if mysql_connection_config is defined %}
  {%- set mysql_connection_user = mysql_connection_config.user %}
  {%- set mysql_connection_pass = mysql_connection_config.password %}
{%- else %}
  {%- set mysql_connection_user = 'root' %}
  {%- set mysql_connection_pass = '' %}
{%- endif %}

{%- for database_name, database in server.get('database', {}).iteritems() %}

mysql_database_{{ database_name }}:
  mysql_database.present:
  - name: {{ database_name }}
  - connection_user: {{ mysql_connection_user }}
  - connection_pass: {{ mysql_connection_pass }}
  - connection_unix_socket: {{ mysql_connection_unix_socket }}
  - connection_charset: {{ mysql_connection_charset }}

{%- for user in database.users %}

mysql_user_{{ user.name }}_{{ database_name }}_{{ user.host }}:
  mysql_user.present:
  - host: '{{ user.host }}'
  - name: '{{ user.name }}'
  - password: {{ user.password }}
  - use:
    - mysql_database: mysql_database_{{ database_name }}

mysql_grants_{{ user.name }}_{{ database_name }}_{{ user.host }}:
  mysql_grants.present:
  - grant: {{ user.rights }}
  - database: '{{ database_name }}.*'
  - user: '{{ user.name }}'
  - host: '{{ user.host }}'
  - require:
    - mysql_user: mysql_user_{{ user.name }}_{{ database_name }}_{{ user.host }}
    - mysql_database: mysql_database_{{ database_name }}
  - use:
    - mysql_database: mysql_database_{{ database_name }}

{%- endfor %}

{%- if database.initial_data is defined %}

/root/mysql/scripts/restore_{{ database_name }}.sh:
  file.managed:
  - source: salt://mysql/conf/restore.sh
  - mode: 770
  - template: jinja
  - defaults:
    database_name: {{ database_name }}
  - require: 
    - file: mysql_dirs
    - mysql_database: mysql_database_{{ database_name }}

restore_mysql_database_{{ database_name }}:
  cmd.run:
  - name: /root/mysql/scripts/restore_{{ database_name }}.sh
  - unless: "[ -f /root/mysql/flags/{{ database_name }}-installed ]"
  - cwd: /root
  - require:
    - file: /root/mysql/scripts/restore_{{ database_name }}.sh

{%- endif %}

{%- endfor %}

{%- for user in server.get('users', []) %}

mysql_user_{{ user.name }}_{{ user.host }}:
  mysql_user.present:
  - host: '{{ user.host }}'
  - name: '{{ user.name }}'
  {%- if user.password is defined %}
  - password: {{ user.password }}
  {%- else %}
  - allow_passwordless: True
  {%- endif %}
  - connection_user: {{ mysql_connection_user }}
  - connection_pass: {{ mysql_connection_pass }}
  - connection_unix_socket: {{ mysql_connection_unix_socket }}
  - connection_charset: {{ mysql_connection_charset }}

{%- endfor %}

{%- endif %}
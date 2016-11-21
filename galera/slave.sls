{%- from "galera/map.jinja" import slave with context %}
{%- if slave.enabled %}

galera_bootstrap_init_config:
  file.managed:
  - name: {{ slave.config }}
  - source: salt://galera/files/my.cnf
  - mode: 644
  - template: jinja
  - makedirs: true


{%- if grains.os_family == 'RedHat' %}
xtrabackup_repo:
  pkg.installed:
  - sources:
    - percona-release: {{ slave.xtrabackup_repo }}
  - require_in:
    - pkg: galera_packages

# Workaround https://bugs.launchpad.net/percona-server/+bug/1490144
xtrabackup_repo_fix:
  cmd.run:
    - name: |
        sed -i 's,enabled\ =\ 1,enabled\ =\ 1\nexclude\ =\ Percona-XtraDB-\*\ Percona-Server-\*,g' /etc/yum.repos.d/percona-release.repo
    - unless: 'grep "exclude = Percona-XtraDB-\*" /etc/yum.repos.d/percona-release.repo'
    - watch:
      - pkg: xtrabackup_repo
    - require_in:
      - pkg: galera_packages
{%- endif %}

galera_packages:
  pkg.installed:
  - names: {{ slave.pkgs }}
  - refresh: true
  - require:
      - file: galera_bootstrap_init_config

galera_log_dir:
  file.directory:
  - name: /var/log/mysql
  - makedirs: true
  - mode: 755
  - require:
    - pkg: galera_packages

{%- if grains.os_family == 'Debian' %}
galera_run_dir:
  file.directory:
  - name: /var/run/mysqld
  - makedirs: true
  - mode: 755
  - user: mysql
  - group: root
  - require:
    - pkg: galera_packages

galera_purge_init:
  file.absent:
  - name: /etc/init/mysql.conf
  - require:
    - pkg: galera_packages

galera_conf_debian:
  file.managed:
  - name: /etc/mysql/debian.cnf
  - template: jinja
  - source: salt://galera/files/debian.cnf
  - mode: 640
  - require:
    - pkg: galera_packages

{%- endif %}

galera_bootstrap_stop_service:
  service.dead:
  - name: {{ slave.service }}
  - require:
    - pkg: galera_packages

galera_config:
  file.managed:
  - name: {{ slave.config }}
  - source: salt://galera/files/my.cnf
  - mode: 644
  - template: jinja
  - require_in: 
    - service: galera_service

galera_service:
  service.running:
  - name: {{ slave.service }}
  - enable: true
  - reload: true

{%- endif %}

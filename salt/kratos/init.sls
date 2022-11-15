# Copyright Security Onion Solutions LLC and/or licensed to Security Onion Solutions LLC under one
# or more contributor license agreements. Licensed under the Elastic License 2.0 as shown at 
# https://securityonion.net/license; you may not use this file except in compliance with the
# Elastic License 2.0.

{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states %}
{% from 'docker/docker.map.jinja' import DOCKER %}
{% from 'vars/globals.map.jinja' import GLOBALS %}

# Add Kratos Group
kratosgroup:
  group.present:
    - name: kratos
    - gid: 928

# Add Kratos user
kratos:
  user.present:
    - uid: 928
    - gid: 928
    - home: /opt/so/conf/kratos
    
kratosdir:
  file.directory:
    - name: /opt/so/conf/kratos/db
    - user: 928
    - group: 928
    - makedirs: True

kratoslogdir:
  file.directory:
    - name: /opt/so/log/kratos
    - user: 928
    - group: 928
    - makedirs: True

kratossync:
  file.recurse:
    - name: /opt/so/conf/kratos
    - source: salt://kratos/files
    - user: 928
    - group: 928
    - file_mode: 600
    - template: jinja
    - defaults:
        GLOBALS: {{ GLOBALS }}

kratos_schema:
  file.exists:
    - name: /opt/so/conf/kratos/schema.json
  
kratos_yaml:
  file.exists:
    - name: /opt/so/conf/kratos/kratos.yaml

so-kratos:
  docker_container.running:
    - image: {{ GLOBALS.registry_host }}:5000/{{ GLOBALS.image_repo }}/so-kratos:{{ GLOBALS.so_version }}
    - hostname: kratos
    - name: so-kratos
    - networks:
      - sosnet:
        - ipv4_address: {{ DOCKER.containers['so-kratos'].ip }}
    - binds:
      - /opt/so/conf/kratos/schema.json:/kratos-conf/schema.json:ro    
      - /opt/so/conf/kratos/kratos.yaml:/kratos-conf/kratos.yaml:ro
      - /opt/so/log/kratos/:/kratos-log:rw
      - /opt/so/conf/kratos/db:/kratos-data:rw
    - port_bindings:
      - 0.0.0.0:4433:4433
      - 0.0.0.0:4434:4434
    - restart_policy: unless-stopped
    - watch:
      - file: /opt/so/conf/kratos
    - require:
      - file: kratos_schema
      - file: kratos_yaml
      - file: kratoslogdir
      - file: kratosdir

append_so-kratos_so-status.conf:
  file.append:
    - name: /opt/so/conf/so-status/so-status.conf
    - text: so-kratos

wait_for_kratos:
  http.wait_for_successful_query:
    - name: 'http://{{ GLOBALS.manager }}:4434/'
    - ssl: True
    - verify_ssl: False
    - status:
      - 200
      - 301
      - 302
      - 404
    - status_type: list
    - wait_for: 300
    - request_interval: 10
    - require:
      -  docker_container: so-kratos

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}

#!/bin/bash
set -e

RANGER_HOME=/opt/ranger-2.4.0-admin

echo "============================================"
echo "🚀 Iniciando Ranger Admin Setup"
echo "============================================"

# ----- Aguarda PostgreSQL -----
echo "⏳ Aguardando PostgreSQL em ${db_host:-postgres}:5432..."
while ! nc -z "${db_host:-postgres}" 5432; do
  sleep 2
done
echo "✅ PostgreSQL disponível!"

# ----- Aguarda Keycloak (se configurado) -----
if [ -n "$ranger_openid_provider_url" ]; then
  KEYCLOAK_HOST=$(echo $ranger_openid_provider_url | sed -E 's|http[s]?://([^:/]+).*|\1|')
  KEYCLOAK_PORT=$(echo $ranger_openid_provider_url | sed -E 's|http[s]?://[^:]+:([0-9]+).*|\1|')
  KEYCLOAK_PORT=${KEYCLOAK_PORT:-8080}
  
  echo "⏳ Aguardando Keycloak em ${KEYCLOAK_HOST}:${KEYCLOAK_PORT}..."
  while ! nc -z "${KEYCLOAK_HOST}" "${KEYCLOAK_PORT}"; do
    sleep 2
  done
  echo "✅ Keycloak disponível!"
fi

# ----- Configura variáveis no install.properties -----
echo "📝 Configurando install.properties..."

sed -i "s|^db_host=.*|db_host=${db_host:-postgres}|g" $RANGER_HOME/install.properties
sed -i "s|^db_name=.*|db_name=${db_name:-ranger}|g" $RANGER_HOME/install.properties
sed -i "s|^db_user=.*|db_user=${db_user:-ranger}|g" $RANGER_HOME/install.properties
sed -i "s|^db_password=.*|db_password=${db_password:-ranger}|g" $RANGER_HOME/install.properties
sed -i "s|^db_root_user=.*|db_root_user=${db_root_user:-ranger}|g" $RANGER_HOME/install.properties
sed -i "s|^db_root_password=.*|db_root_password=${db_root_password:-ranger}|g" $RANGER_HOME/install.properties

# ----- Configura OIDC se habilitado -----
if [ "$SUPPORTED_AUTHENTICATION_METHODS" == "openidconnect" ] && [ -n "$ranger_openid_provider_url" ]; then
  echo "🔐 Configurando autenticação OpenID Connect..."
  
  # Cria/atualiza arquivo de configuração do OIDC
  cat >> $RANGER_HOME/install.properties << EOF

# ----- OpenID Connect Configuration -----
ranger.authentication.method=NONE
ranger.sso.enabled=false
EOF

  # Configura o ranger-admin-site.xml após setup
  OIDC_CONFIG="
ranger.authentication.method=NONE
ranger.sso.browser.useragent=Mozilla,Opera,Chrome,Safari
ranger.sso.enabled=false
"
fi

# ----- Executa o setup do Ranger -----
echo "🔧 Executando setup.sh..."
cd $RANGER_HOME

# Setup não-interativo
./setup.sh

# ----- Configura OIDC no ranger-admin-site.xml (pós-setup) -----
if [ "$SUPPORTED_AUTHENTICATION_METHODS" == "openidconnect" ] && [ -n "$ranger_openid_provider_url" ]; then
  echo "🔐 Aplicando configuração OIDC no ranger-admin-site.xml..."
  
  SITE_XML="$RANGER_HOME/ews/webapp/WEB-INF/classes/conf/ranger-admin-site.xml"
  
  # Adiciona configurações OIDC antes do </configuration>
  if [ -f "$SITE_XML" ]; then
    sed -i 's|</configuration>||g' $SITE_XML
    cat >> $SITE_XML << EOF

  <!-- OpenID Connect Configuration -->
  <property>
    <name>ranger.authentication.method</name>
    <value>NONE</value>
  </property>
  <property>
    <name>ranger.sso.enabled</name>
    <value>true</value>
  </property>
  <property>
    <name>ranger.sso.providerurl</name>
    <value>${ranger_openid_provider_url}/protocol/openid-connect/auth</value>
  </property>
  <property>
    <name>ranger.sso.browser.useragent</name>
    <value>Mozilla,Opera,Chrome,Safari,Edge</value>
  </property>
  <property>
    <name>ranger.sso.token.audiences</name>
    <value>${ranger_openid_client_id}</value>
  </property>
  
</configuration>
EOF
    echo "✅ Configuração OIDC aplicada!"
  fi
fi

# ----- Inicia o Ranger Admin -----
echo "============================================"
echo "🚀 Iniciando Ranger Admin na porta 6080..."
echo "============================================"

cd $RANGER_HOME
./ews/ranger-admin-services.sh start

# Mantém o container rodando e mostra os logs
echo "📋 Exibindo logs do Ranger Admin..."
sleep 5

if [ -f "$RANGER_HOME/ews/logs/ranger-admin-$(hostname)-*.log" ]; then
  tail -f $RANGER_HOME/ews/logs/ranger-admin-*.log
else
  tail -f $RANGER_HOME/ews/logs/access_log.* 2>/dev/null || \
  tail -f /var/log/ranger/*.log 2>/dev/null || \
  while true; do sleep 3600; done
fi

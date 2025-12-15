# Apache Ranger Docker Setup

## Problemas Comuns de Download

Se você encontrar erros ao baixar o Apache Ranger durante o build do Docker, siga estes passos:

### 1. Verificar Versão Disponível

A versão padrão é `2.4.0`. Se esta versão não estiver disponível, você pode:

1. Verificar versões disponíveis em: https://archive.apache.org/dist/ranger/
2. Alterar a versão no `dockerfile`:

```dockerfile
ENV RANGER_VERSION=2.3.0  # ou outra versão disponível
```

### 2. Versões Testadas

- 2.4.0 (padrão)
- 2.3.0
- 2.2.0

### 3. Solução de Problemas

O Dockerfile agora tenta baixar de múltiplas fontes:
- archive.apache.org
- downloads.apache.org  
- dlcdn.apache.org

Se todas falharem, verifique:
- Conectividade com a internet
- Firewall/proxy bloqueando downloads
- Se a versão especificada realmente existe

### 4. Build Manual

Se o download automático falhar, você pode:

1. Baixar manualmente o arquivo:
```bash
wget https://archive.apache.org/dist/ranger/2.4.0/apache-ranger-2.4.0.tar.gz
```

2. Colocar o arquivo na pasta `ranger-poc/` e modificar o Dockerfile para usar COPY em vez de wget.


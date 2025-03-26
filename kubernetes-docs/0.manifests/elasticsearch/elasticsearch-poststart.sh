#!/bin/bash

ES_URL=https://localhost:9200
ELASTIC_USER="elastic"
TEMPLATE_NAME=prod-template
INDEX_PATTERN="prod-*"
SHARD_COUNT=1
REPLICA_COUNT=1
ILM_POLICY_NAME=prod-ilm-policy

echo "elasticsearch password: $ELASTIC_PASSWORD"

# Exit if ELASTIC_PASSWORD in unset
if [ -z "${ELASTIC_PASSWORD}" ]; then
  echo "ELASTIC_PASSWORD variable is missing, exiting"
  exit 1
fi

echo "Waiting for Elasticsearch to be ready..."

until curl -k -u "elastic:${ELASTIC_PASSWORD}" -s -o /dev/null -w '%{http_code}' $ES_URL | grep -q "200"; do
  sleep 3
done

echo "Creating ILM policy..."
curl -k -XPUT -u "elastic:${ELASTIC_PASSWORD}" "$ES_URL/_ilm/policy/$ILM_POLICY_NAME" -H 'Content-Type: application/json' -d '
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "set_priority": {
            "priority": 1
          },
          "rollover": {
            "max_size": "30gb",
            "max_age": "7d"
          }
        }
      },
      "delete": {
        "min_age": "7d",
        "actions": {
          "delete": {
            "delete_searchable_snapshot": true
          }
        }
      }
    }
  }
}'

echo "Creating index template and attaching ILM policy..."
curl -k -XPUT -u "elastic:${ELASTIC_PASSWORD}" "$ES_URL/_index_template/$TEMPLATE_NAME" -H 'Content-Type: application/json' -d '
{
  "index_patterns": ["'"$INDEX_PATTERN"'"],
  "priority": 0,
  "template": {
    "settings": {
      "number_of_shards": '"$SHARD_COUNT"',
      "number_of_replicas": '"$REPLICA_COUNT"',
      "index.lifecycle.name": "'"$ILM_POLICY_NAME"'"
    },
    "mappings": {
      "properties": {
        "@timestamp": {
          "type": "date"
        },
        "message": {
          "type": "text"
        }
      }
    },
    "aliases": {}
  }
}
'

echo "Lifecycle postStart completed."
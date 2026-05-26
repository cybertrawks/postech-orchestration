# k8s/gamestore

Manifestos Kubernetes dos microsserviços da FIAP Cloud Games.

Os SealedSecrets (`users-api-secret`, `registry-pull-secret`) sao gerados
com `kubeseal` e versionados aqui. Os Secrets brutos NUNCA sao commitados.
